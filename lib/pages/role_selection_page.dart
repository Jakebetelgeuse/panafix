import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'home_page.dart';
import 'technician_home_page.dart';

class RoleSelectionPage extends StatefulWidget {
  const RoleSelectionPage({super.key});

  @override
  State<RoleSelectionPage> createState() => _RoleSelectionPageState();
}

class _RoleSelectionPageState extends State<RoleSelectionPage> {
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final identityDocumentController = TextEditingController();

  String selectedRole = 'client';
  String? selectedCity;
  bool isSaving = false;

  final List<String> venezuelaCities = const [
    'Caracas',
    'Maracaibo',
    'Valencia',
    'Barquisimeto',
    'Maracay',
    'Puerto La Cruz',
    'Maturin',
    'Ciudad Guayana',
    'San Cristobal',
    'Merida',
    'Cumana',
    'Barcelona',
    'Cabimas',
    'Punto Fijo',
    'Los Teques',
    'Guarenas',
    'Guatire',
    'Acarigua',
    'Puerto Ordaz',
    'La Guaira',
  ];

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    nameController.text = user?.displayName ?? '';
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    identityDocumentController.dispose();
    super.dispose();
  }

  Future<void> saveRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final name = nameController.text.trim();
    final phone = phoneController.text.trim();
    final identityDocument = identityDocumentController.text.trim();

    if (name.isEmpty || phone.isEmpty || selectedCity == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa nombre, telefono y ciudad.')),
      );
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      await user.updateDisplayName(name);

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'name': name,
        'email': user.email ?? '',
        'phone': phone,
        'identityDocument': identityDocument,
        'city': selectedCity,
        'role': selectedRole,
        'needsRoleSelection': false,
        'photoUrl': user.photoURL ?? '',
        'rating': 5.0,
        'reviewsCount': 0,
        'isAvailable': selectedRole == 'technician',
        'verificationStatus':
            selectedRole == 'technician' ? 'pending' : 'approved',
        'clientVerificationStatus': selectedRole == 'client'
            ? (identityDocument.isEmpty ? 'not_provided' : 'provided')
            : '',
        'subscriptionPlan': 'basic',
        'subscriptionStatus': 'inactive',
        'subscriptionPriority': 0,
        'showOnboardingGuide': true,
        'availableDays':
            selectedRole == 'technician' ? ['Lun', 'Mar', 'Mie', 'Jue', 'Vie'] : [],
        'workStart': selectedRole == 'technician' ? '08:00' : '',
        'workEnd': selectedRole == 'technician' ? '18:00' : '',
        'categories': <String>[],
        'services': <String>[],
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => selectedRole == 'technician'
              ? const TechnicianHomePage()
              : const HomePage(),
        ),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar el perfil: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  Widget _roleCard({
    required String title,
    required String subtitle,
    required String value,
    required IconData icon,
  }) {
    final isSelected = selectedRole == value;

    return Expanded(
      child: InkWell(
        onTap: isSaving
            ? null
            : () {
                setState(() {
                  selectedRole = value;
                });
              },
        borderRadius: BorderRadius.circular(24),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFFF7A00) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isSelected ? const Color(0xFFFF7A00) : const Color(0xFFE7DED4),
            ),
            boxShadow: [
              if (isSelected)
                BoxShadow(
                  color: const Color(0xFFFF7A00).withOpacity(0.28),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : const Color(0xFFFF7A00),
                size: 30,
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF1B130C),
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: TextStyle(
                  color: isSelected ? const Color(0xFFFFEAD8) : Colors.black54,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7ED),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1B130C),
                      borderRadius: BorderRadius.circular(34),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.handshake_rounded,
                          color: Color(0xFFFF7A00),
                          size: 42,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Antes de entrar...',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Dinos como usaras Panafix para preparar tu cuenta. Prometemos no hacerlo mas dramatico que armar una cama sin instrucciones.',
                          style: TextStyle(
                            color: Color(0xFFEADFD4),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      _roleCard(
                        title: 'Cliente',
                        subtitle: 'Quiero pedir servicios para mi hogar.',
                        value: 'client',
                        icon: Icons.home_rounded,
                      ),
                      const SizedBox(width: 12),
                      _roleCard(
                        title: 'Tecnico',
                        subtitle: 'Quiero recibir solicitudes de trabajo.',
                        value: 'technician',
                        icon: Icons.construction_rounded,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 22,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        TextField(
                          controller: nameController,
                          decoration: const InputDecoration(
                            labelText: 'Nombre completo',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Telefono',
                            prefixIcon: Icon(Icons.phone_outlined),
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: selectedCity,
                          decoration: const InputDecoration(
                            labelText: 'Ciudad',
                            prefixIcon: Icon(Icons.location_city_outlined),
                            border: OutlineInputBorder(),
                          ),
                          items: venezuelaCities.map((city) {
                            return DropdownMenuItem<String>(
                              value: city,
                              child: Text(city),
                            );
                          }).toList(),
                          onChanged: isSaving
                              ? null
                              : (value) {
                                  setState(() {
                                    selectedCity = value;
                                  });
                                },
                        ),
                        if (selectedRole == 'client') ...[
                          const SizedBox(height: 12),
                          TextField(
                            controller: identityDocumentController,
                            keyboardType: TextInputType.text,
                            decoration: const InputDecoration(
                              labelText: 'Cedula de identidad (opcional)',
                              prefixIcon: Icon(Icons.badge_outlined),
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: isSaving ? null : saveRole,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF7A00),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                            ),
                            child: isSaving
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Entrar a Panafix'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
