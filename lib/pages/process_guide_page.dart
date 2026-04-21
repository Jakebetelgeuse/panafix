import 'package:flutter/material.dart';

class ProcessGuidePage extends StatelessWidget {
  final bool isTechnician;

  const ProcessGuidePage.client({super.key}) : isTechnician = false;

  const ProcessGuidePage.technician({super.key}) : isTechnician = true;

  @override
  Widget build(BuildContext context) {
    final title = isTechnician ? 'Guia del tecnico' : 'Guia del cliente';
    final subtitle = isTechnician
        ? 'Como trabajar en Panafix sin enredos.'
        : 'Como pedir un servicio y sentirte en control.';
    final steps = isTechnician ? _technicianSteps : _clientSteps;

    return Scaffold(
      backgroundColor: const Color(0xFFFFF7ED),
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1B130C), Color(0xFFFF7A00)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    isTechnician
                        ? Icons.engineering_outlined
                        : Icons.home_repair_service_outlined,
                    color: Colors.white,
                    size: 38,
                  ),
                  const SizedBox(height: 14),
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
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFFFFE7CC),
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            ...steps.asMap().entries.map((entry) {
              final index = entry.key + 1;
              final step = entry.value;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFFFD6A3)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withValues(alpha: 0.08),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF7A00),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Text(
                        '$index',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            step.title,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            step.body,
                            style: const TextStyle(
                              color: Color(0xFF6D5E4F),
                              height: 1.42,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF1B130C),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Text(
                isTechnician
                    ? 'Tip Panafix: completa tu perfil, foto, pago movil y verificacion. Mientras mas claro se vea tu trabajo, mas confianza generas.'
                    : 'Tip Panafix: el pago queda retenido y Panafix revisa el comprobante antes de avisarle al tecnico que puede ir en camino.',
                style: const TextStyle(
                  color: Color(0xFFFFE7CC),
                  height: 1.45,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuideStep {
  final String title;
  final String body;

  const _GuideStep(this.title, this.body);
}

const _clientSteps = [
  _GuideStep(
    'Elige categoria y tecnico',
    'Busca el servicio, revisa tecnicos disponibles u offline y escoge quien te inspire mas confianza.',
  ),
  _GuideStep(
    'Cuenta que pasa',
    'Describe el problema con detalles simples. Si puedes ser especifica, el tecnico llega mejor preparado.',
  ),
  _GuideStep(
    'Paga con respaldo',
    'La app calcula el monto en bolivares con tasa BCV guardada y te pide referencia, datos del pago movil y comprobante.',
  ),
  _GuideStep(
    'Panafix revisa',
    'Tu pago queda en revision. Cuando se aprueba, el tecnico puede ponerse en camino.',
  ),
  _GuideStep(
    'Seguimiento y cierre',
    'Puedes ver la aproximacion, usar chat solo mientras va en camino y luego confirmar cuando el trabajo queda listo.',
  ),
];

const _technicianSteps = [
  _GuideStep(
    'Completa tu vitrina',
    'Agrega nombre, ciudad, foto, servicios, horario, radio de trabajo y datos de pago movil para poder cobrar.',
  ),
  _GuideStep(
    'Recibe solicitudes',
    'Apareces en las categorias aunque estes fuera de horario; si no estas disponible, la app muestra cuando vuelves.',
  ),
  _GuideStep(
    'Espera pago aprobado',
    'No salgas hasta que Panafix apruebe el pago del cliente. Asi el dinero queda retenido antes de que vayas en camino.',
  ),
  _GuideStep(
    'Trabaja y actualiza estado',
    'Marca cuando vas en camino, llegaste y terminaste. El chat existe solo mientras estas en camino.',
  ),
  _GuideStep(
    'Solicita tu pago',
    'Cuando Panafix autoriza tu pago despues del trabajo completado, pide tu pago retenido de lunes a viernes entre 10:00 a.m. y 4:00 p.m.',
  ),
  _GuideStep(
    'Sube de nivel',
    'Puedes verificarte y activar planes Empresas o Premium para tener mas visibilidad dentro de la app.',
  ),
];
