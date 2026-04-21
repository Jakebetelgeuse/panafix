import 'package:flutter/material.dart';

import 'technicians_page.dart';

class ServicesPage extends StatelessWidget {
  final String category;

  const ServicesPage({
    super.key,
    required this.category,
  });

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

  List<String> getServicesByCategory(String rawCategory) {
    switch (normalizeCategory(rawCategory)) {
      case 'Electricidad':
        return const [
          'Revision electrica',
          'Instalacion de lamparas',
          'Tomacorrientes',
          'Corto circuito',
          'Cableado',
        ];
      case 'Fontaneria':
        return const [
          'Destapar tuberias',
          'Reparacion de fugas',
          'Instalacion de grifos',
          'Revision de bano',
          'Tuberias',
        ];
      case 'Cerrajeria':
        return const [
          'Abrir puerta',
          'Cambio de cerradura',
          'Duplicado de llaves',
          'Revision de cerradura',
        ];
      case 'Internet/TV':
        return const [
          'Instalacion de router',
          'Problemas de internet',
          'Configuracion WiFi',
          'Instalacion de TV',
        ];
      case 'Electrodomesticos':
        return const [
          'Reparacion de nevera',
          'Reparacion de lavadora',
          'Reparacion de cocina',
          'Mantenimiento',
        ];
      case 'Albanileria':
        return const [
          'Frisado de pared',
          'Pegar ceramica',
          'Reparacion de pared',
          'Trabajos de cemento',
          'Acabados',
        ];
      case 'Pintura':
        return const [
          'Pintura interior',
          'Pintura exterior',
          'Impermeabilizacion',
          'Acabados decorativos',
          'Retoques',
        ];
      case 'Carpinteria':
        return const [
          'Reparacion de puertas',
          'Closets',
          'Muebles a medida',
          'Reparacion de muebles',
          'Instalacion de repisas',
        ];
      case 'Limpieza':
        return const [
          'Limpieza de hogar',
          'Limpieza profunda',
          'Limpieza de oficina',
          'Limpieza post obra',
          'Limpieza de tapiceria',
        ];
      default:
        return const ['Servicio general'];
    }
  }

  IconData getCategoryIcon(String rawCategory) {
    switch (normalizeCategory(rawCategory)) {
      case 'Electricidad':
        return Icons.flash_on;
      case 'Fontaneria':
        return Icons.plumbing;
      case 'Cerrajeria':
        return Icons.key;
      case 'Internet/TV':
        return Icons.router;
      case 'Electrodomesticos':
        return Icons.kitchen;
      case 'Albanileria':
        return Icons.construction;
      case 'Pintura':
        return Icons.format_paint;
      case 'Carpinteria':
        return Icons.carpenter;
      case 'Limpieza':
        return Icons.cleaning_services;
      default:
        return Icons.build;
    }
  }

  @override
  Widget build(BuildContext context) {
    final normalizedCategory = normalizeCategory(category);
    final services = getServicesByCategory(normalizedCategory);

    return Scaffold(
      appBar: AppBar(
        title: Text(normalizedCategory),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF1B130C),
                      Color(0xFF6B3A10),
                      Color(0xFFFF9C33),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(32),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      normalizedCategory,
                      style: const TextStyle(
                        color: Color(0xFFFFDDB7),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Selecciona el servicio exacto que necesitas y mira quienes estan disponibles.',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: ListView.builder(
                  itemCount: services.length,
                  itemBuilder: (context, index) {
                    final service = services[index];

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 22,
                            offset: const Offset(0, 16),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFEDD8),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Icon(
                              getCategoryIcon(normalizedCategory),
                              color: const Color(0xFFFF7A00),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  service,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  normalizedCategory,
                                  style: const TextStyle(
                                    color: Color(0xFF756B61),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios, size: 18),
                        ],
                      ),
                    ).applyInkWell(() {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TechniciansPage(
                            category: normalizedCategory,
                            service: service,
                          ),
                        ),
                      );
                    });
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension on Widget {
  Widget applyInkWell(VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: this,
      ),
    );
  }
}
