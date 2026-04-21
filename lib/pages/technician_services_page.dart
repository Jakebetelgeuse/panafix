import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class TechnicianServicesPage extends StatelessWidget {
  const TechnicianServicesPage({super.key});

  static const List<String> allCategories = [
    'Electricidad',
    'Fontaneria',
    'Cerrajeria',
    'Internet/TV',
    'Electrodomesticos',
    'Albanileria',
    'Limpieza',
    'Mas servicios',
  ];

  static const Map<String, List<String>> servicesByCategory = {
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
      'Paredes',
      'Frisos',
      'Pisos',
      'Reparaciones menores',
    ],
    'Limpieza': [
      'Limpieza de hogar',
      'Limpieza profunda',
      'Limpieza de oficina',
      'Limpieza post obra',
      'Limpieza de tapiceria',
    ],
    'Mas servicios': [
      'Pintura',
      'Carpinteria',
      'Aire acondicionado',
      'Soldadura',
    ],
  };

  Stream<QuerySnapshot<Map<String, dynamic>>> getServices() {
    final user = FirebaseAuth.instance.currentUser;

    return FirebaseFirestore.instance
        .collection('services')
        .where('technicianId', isEqualTo: user?.uid)
        .snapshots();
  }

  List<String> availableServices(List<String> categories) {
    final result = <String>[];
    for (final category in categories) {
      for (final service in servicesByCategory[category] ?? <String>[]) {
        if (!result.contains(service)) result.add(service);
      }
    }
    return result;
  }

  Future<void> updateTechnicianCatalog({
    required List<String> categories,
    required List<String> services,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'categories': categories,
      'services': services,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Widget serviceSetupCard(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? {};
        final selectedCategories =
            List<String>.from(data['categories'] ?? <String>[]);
        final selectedServices = List<String>.from(data['services'] ?? <String>[]);
        final services = availableServices(selectedCategories);

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFFFD6A3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Categorias donde apareces',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              const Text(
                'Elige aqui en que categorias y servicios quieres salir cuando un cliente busque tecnicos.',
                style: TextStyle(color: Colors.black54, height: 1.35),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: allCategories.map((category) {
                  final selected = selectedCategories.contains(category);
                  return FilterChip(
                    selected: selected,
                    label: Text(category),
                    selectedColor: const Color(0xFFFFE2BF),
                    checkmarkColor: const Color(0xFFFF7A00),
                    onSelected: (value) {
                      final nextCategories = [...selectedCategories];
                      if (value) {
                        if (!nextCategories.contains(category)) {
                          nextCategories.add(category);
                        }
                      } else {
                        nextCategories.remove(category);
                      }
                      final allowedServices =
                          availableServices(nextCategories).toSet();
                      final nextServices = selectedServices
                          .where((service) => allowedServices.contains(service))
                          .toList();
                      updateTechnicianCatalog(
                        categories: nextCategories,
                        services: nextServices,
                      );
                    },
                  );
                }).toList(),
              ),
              if (services.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Servicios activos',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                ...services.map((service) {
                  return CheckboxListTile(
                    value: selectedServices.contains(service),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(service),
                    onChanged: (value) {
                      final nextServices = [...selectedServices];
                      if (value == true) {
                        if (!nextServices.contains(service)) {
                          nextServices.add(service);
                        }
                      } else {
                        nextServices.remove(service);
                      }
                      updateTechnicianCatalog(
                        categories: selectedCategories,
                        services: nextServices,
                      );
                    },
                  );
                }),
              ],
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: getServices(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Error al cargar servicios: ${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                serviceSetupCard(context),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(
                        Icons.design_services_outlined,
                        size: 72,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Todavia no has agregado servicios con precio',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Primero selecciona tus categorias. Luego agrega servicios con precio para mostrarlos mejor.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }

          docs.sort((a, b) {
            final aTime = a.data()['createdAt'] as Timestamp?;
            final bTime = b.data()['createdAt'] as Timestamp?;

            if (aTime == null && bTime == null) return 0;
            if (aTime == null) return 1;
            if (bTime == null) return -1;

            return bTime.compareTo(aTime);
          });

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              serviceSetupCard(context),
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF8C1A), Color(0xFFFFB14A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tus servicios publicados',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${docs.length} servicio(s) activos para mostrar a clientes.',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              ...docs.map((doc) {
                final data = doc.data();
                final serviceName = data['serviceName']?.toString() ?? '';
                final category = data['category']?.toString() ?? '';
                final basePrice = ((data['basePrice'] ?? 0) as num).toDouble();
                final finalPrice = ((data['finalPrice'] ?? 0) as num).toDouble();

                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor:
                                    Colors.orange.withOpacity(0.14),
                                child: const Icon(
                                  Icons.handyman,
                                  color: Colors.orange,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      serviceName,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      category,
                                      style: const TextStyle(
                                        color: Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8F8F8),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Tu ganancia estimada',
                                  style: TextStyle(
                                    color: Colors.black54,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '\$${basePrice.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.green,
                                  ),
                                ),
                                if (finalPrice > 0) ...[
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Panafix muestra tu servicio al cliente con el precio final de la plataforma.',
                                    style: TextStyle(
                                      color: Colors.black54,
                                      fontSize: 12,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}
