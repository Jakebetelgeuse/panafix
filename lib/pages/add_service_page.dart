import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AddServicePage extends StatefulWidget {
  const AddServicePage({super.key});

  @override
  State<AddServicePage> createState() => _AddServicePageState();
}

class _AddServicePageState extends State<AddServicePage> {
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController priceController = TextEditingController();

  bool isSaving = false;
  String? selectedCategory;
  String? selectedService;

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
      'Cableado de red',
    ],
    'Electrodomesticos': [
      'Reparacion de nevera',
      'Reparacion de lavadora',
      'Reparacion de secadora',
      'Reparacion de cocina',
      'Revision general',
    ],
    'Albanileria': [
      'Frisado de pared',
      'Pegar ceramica',
      'Reparacion de pared',
      'Trabajos de cemento',
      'Acabados',
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

  @override
  void dispose() {
    descriptionController.dispose();
    priceController.dispose();
    super.dispose();
  }

  Future<void> saveService() async {
    final user = FirebaseAuth.instance.currentUser;
    final serviceName = selectedService ?? '';
    final description = descriptionController.text.trim();
    final priceText = priceController.text.trim();

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes iniciar sesion.')),
      );
      return;
    }

    if (selectedCategory == null || selectedService == null || priceText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Completa la categoria, el servicio y el precio.'),
        ),
      );
      return;
    }

    final double? basePrice = double.tryParse(priceText);

    if (basePrice == null || basePrice <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa un precio valido.')),
      );
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      final userDoc = await userRef.get();
      final userData = userDoc.data() ?? {};
      final technicianName =
          (userData['name'] ?? user.displayName ?? 'Tecnico').toString();

      const appCommissionPercent = 15;
      final double finalPrice =
          double.parse((basePrice * 1.15).toStringAsFixed(2));
      final double appCommission =
          double.parse((finalPrice - basePrice).toStringAsFixed(2));

      await FirebaseFirestore.instance.collection('services').add({
        'technicianId': user.uid,
        'technicianName': technicianName,
        'category': selectedCategory,
        'serviceName': serviceName,
        'description': description,
        'basePrice': basePrice,
        'appCommission': appCommission,
        'appCommissionPercent': appCommissionPercent,
        'finalPrice': finalPrice,
        'priceFrom': finalPrice,
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final currentServices = List<String>.from(userData['services'] ?? []);
      if (!currentServices.contains(serviceName)) {
        currentServices.add(serviceName);
      }

      final currentCategories = List<String>.from(userData['categories'] ?? []);
      if (selectedCategory != null && !currentCategories.contains(selectedCategory)) {
        currentCategories.add(selectedCategory!);
      }

      await userRef.set({
        'services': currentServices,
        'categories': currentCategories,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Servicio agregado correctamente.')),
      );

      setState(() {
        selectedCategory = null;
        selectedService = null;
      });
      descriptionController.clear();
      priceController.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar servicio: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final previewBasePrice = double.tryParse(priceController.text.trim()) ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agregar servicio'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              value: selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Categoria',
              ),
              items: servicesByCategory.keys.map((category) {
                return DropdownMenuItem<String>(
                  value: category,
                  child: Text(category),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedCategory = value;
                  selectedService = null;
                });
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: selectedService,
              decoration: const InputDecoration(
                labelText: 'Servicio',
              ),
              items: (selectedCategory != null
                      ? servicesByCategory[selectedCategory]!
                      : <String>[])
                  .map((service) {
                return DropdownMenuItem<String>(
                  value: service,
                  child: Text(service),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedService = value;
                });
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Descripcion',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Tu precio',
                hintText: 'Ej: 20',
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.orange.withOpacity(0.25),
                ),
              ),
              child: Text(
                previewBasePrice > 0
                    ? 'Este sera tu precio base: \$${previewBasePrice.toStringAsFixed(2)}'
                    : 'Ingresa el precio que quieres cobrar por este servicio.',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isSaving ? null : saveService,
                child: isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.4,
                        ),
                      )
                    : const Text('Guardar servicio'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
