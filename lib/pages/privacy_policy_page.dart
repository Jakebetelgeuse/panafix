import 'package:flutter/material.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

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
        title: const Text('Politica de privacidad'),
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
                  Color(0xFF2563EB),
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
                  'Privacidad en Panafix',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Este documento resume como Panafix recopila, usa y protege la informacion de clientes y tecnicos.',
                  style: TextStyle(
                    color: Color(0xFFDBEAFE),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _section(
            'Informacion que recopilamos',
            'Panafix puede recopilar nombre, correo, telefono, ciudad, informacion del perfil, datos de servicios solicitados u ofrecidos, reseñas, historial de ordenes, soporte y datos operativos relacionados con el uso de la plataforma.',
          ),
          _section(
            'Uso de la informacion',
            'La informacion se usa para crear cuentas, conectar clientes con tecnicos, coordinar servicios, gestionar pagos, permitir soporte, mejorar la experiencia y mantener la seguridad de la plataforma.',
          ),
          _section(
            'Ubicacion y seguimiento',
            'Cuando un servicio lo requiere, Panafix puede usar ubicacion del cliente y del tecnico para mostrar la aproximacion, facilitar el encuentro y ofrecer soporte ante incidencias.',
          ),
          _section(
            'Pagos y comprobantes',
            'Los datos relacionados con pagos, referencias y comprobantes pueden almacenarse para validar operaciones, resolver incidencias, hacer cortes de pago y cumplir procesos internos de soporte y seguridad.',
          ),
          _section(
            'Proteccion de datos',
            'Panafix procura limitar el acceso a la informacion segun el rol de cada usuario y mantener reglas de acceso en Firebase, aunque el usuario tambien debe proteger sus credenciales y usar informacion real.',
          ),
          _section(
            'Contacto',
            'Si necesitas ayuda sobre esta politica o deseas reportar un problema relacionado con tus datos, puedes comunicarte con soporte oficial de Panafix desde la misma app.',
          ),
        ],
      ),
    );
  }
}
