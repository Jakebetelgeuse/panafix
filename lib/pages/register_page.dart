import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'home_page.dart';
import 'technician_home_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final phoneController = TextEditingController();
  final identityDocumentController = TextEditingController();
  final bioController = TextEditingController();

  String selectedRole = 'client';
  String? selectedCity;
  bool isLoading = false;
  bool acceptsTerms = true;

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
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    phoneController.dispose();
    identityDocumentController.dispose();
    bioController.dispose();
    super.dispose();
  }

  Future<void> register() async {
    final name = nameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final phone = phoneController.text.trim();
    final identityDocument = identityDocumentController.text.trim();
    final bio = bioController.text.trim();

    if (name.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        phone.isEmpty ||
        selectedCity == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa todos los campos principales.')),
      );
      return;
    }

    if (!acceptsTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes aceptar las condiciones de uso.')),
      );
      return;
    }

    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La contrasena debe tener al menos 6 caracteres.'),
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final credential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await credential.user?.updateDisplayName(name);

      await FirebaseFirestore.instance
          .collection('users')
          .doc(credential.user!.uid)
          .set({
        'uid': credential.user!.uid,
        'name': name,
        'email': email,
        'phone': phone,
        'identityDocument': identityDocument,
        'city': selectedCity,
        'role': selectedRole,
        'bio': bio,
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
        'needsRoleSelection': false,
        'showOnboardingGuide': true,
        'availableDays':
            selectedRole == 'technician' ? ['Lun', 'Mar', 'Mie', 'Jue', 'Vie'] : [],
        'workStart': selectedRole == 'technician' ? '08:00' : '',
        'workEnd': selectedRole == 'technician' ? '18:00' : '',
        'categories': <String>[],
        'services': <String>[],
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cuenta creada correctamente.')),
      );

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => selectedRole == 'technician'
              ? const TechnicianHomePage()
              : const HomePage(),
        ),
        (_) => false,
      );
    } on FirebaseAuthException catch (e) {
      String message = 'No se pudo crear la cuenta.';

      if (e.code == 'email-already-in-use') {
        message = 'Ese correo ya esta en uso.';
      } else if (e.code == 'invalid-email') {
        message = 'El correo no es valido.';
      } else if (e.code == 'weak-password') {
        message = 'La contrasena es muy debil.';
      } else if (e.code == 'operation-not-allowed') {
        message = 'Email y password no estan activados en Firebase.';
      } else if (e.code == 'network-request-failed') {
        message = 'Revisa tu conexion e intenta otra vez.';
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error inesperado: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Widget _roleCard({
    required String title,
    required String subtitle,
    required String value,
    required IconData icon,
    required List<Color> colors,
  }) {
    final isSelected = selectedRole == value;

    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            selectedRole = value;
          });
        },
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
                    colors: colors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isSelected ? null : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isSelected
                  ? Colors.transparent
                  : const Color(0xFFE2DBD2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withOpacity(0.18)
                      : const Color(0xFFFFEDD8),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  color: isSelected ? Colors.white : const Color(0xFFFF7A00),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF1B130C),
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: TextStyle(
                  color: isSelected
                      ? const Color(0xFFFCE3CD)
                      : const Color(0xFF756B61),
                  height: 1.35,
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
    final isTechnician = selectedRole == 'technician';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear cuenta'),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFF6F4EF),
              Color(0xFFFFF0DE),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
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
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Empieza en Panafix',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 10),
                          Text(
                            'Crea tu perfil para pedir servicios o trabajar como tecnico con seguimiento, pagos y soporte.',
                            style: TextStyle(
                              color: Color(0xFFFCE3CD),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      '¿Como quieres usar la app?',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _roleCard(
                          title: 'Cliente',
                          subtitle: 'Pide servicios, paga con respaldo y sigue el trabajo.',
                          value: 'client',
                          icon: Icons.person_outline,
                          colors: const [Color(0xFF2563EB), Color(0xFF60A5FA)],
                        ),
                        const SizedBox(width: 12),
                        _roleCard(
                          title: 'Tecnico',
                          subtitle: 'Recibe solicitudes, muestra tu perfil y gestiona trabajos.',
                          value: 'technician',
                          icon: Icons.handyman_outlined,
                          colors: const [Color(0xFFFF7A00), Color(0xFFFFB347)],
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Column(
                        children: [
                          TextField(
                            controller: nameController,
                            decoration: const InputDecoration(
                              labelText: 'Nombre completo',
                              prefixIcon: Icon(Icons.badge_outlined),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Correo',
                              prefixIcon: Icon(Icons.mail_outline),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'Telefono',
                              prefixIcon: Icon(Icons.phone_outlined),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: identityDocumentController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: isTechnician
                                  ? 'Cedula o documento'
                                  : 'Cedula de identidad (opcional)',
                              prefixIcon: const Icon(Icons.badge_outlined),
                              hintText: isTechnician
                                  ? 'Opcional por ahora'
                                  : 'Opcional',
                            ),
                          ),
                          const SizedBox(height: 14),
                          DropdownButtonFormField<String>(
                            value: venezuelaCities.contains(selectedCity)
                                ? selectedCity
                                : null,
                            decoration: const InputDecoration(
                              labelText: 'Ciudad',
                              prefixIcon: Icon(Icons.location_city_outlined),
                            ),
                            items: venezuelaCities.map((city) {
                              return DropdownMenuItem<String>(
                                value: city,
                                child: Text(city),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                selectedCity = value;
                              });
                            },
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: passwordController,
                            obscureText: true,
                            decoration: const InputDecoration(
                              labelText: 'Contrasena',
                              prefixIcon: Icon(Icons.lock_outline),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: bioController,
                            maxLines: isTechnician ? 4 : 2,
                            decoration: InputDecoration(
                              labelText: isTechnician
                                  ? 'Presentacion profesional'
                                  : 'Algo sobre ti',
                              prefixIcon: const Icon(Icons.edit_note_outlined),
                              hintText: isTechnician
                                  ? 'Ej: tecnico con experiencia en instalaciones y mantenimiento.'
                                  : 'Ej: prefiero atencion rapida por la tarde.',
                            ),
                          ),
                          const SizedBox(height: 10),
                          CheckboxListTile(
                            value: acceptsTerms,
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            title: const Text(
                              'Acepto continuar con las condiciones de uso de Panafix.',
                            ),
                            onChanged: (value) {
                              setState(() {
                                acceptsTerms = value ?? false;
                              });
                            },
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: isLoading ? null : register,
                              child: Text(
                                isLoading
                                    ? 'Creando cuenta...'
                                    : 'Crear cuenta',
                              ),
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
      ),
    );
  }
}
