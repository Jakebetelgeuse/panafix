import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

class ClientProfilePage extends StatefulWidget {
  const ClientProfilePage({super.key});

  @override
  State<ClientProfilePage> createState() => _ClientProfilePageState();
}

class _ClientProfilePageState extends State<ClientProfilePage> {
  final user = FirebaseAuth.instance.currentUser;
  final TextEditingController nameController = TextEditingController();
  bool isLoading = true;
  bool isSaving = false;
  String? profilePhotoUrl;
  String? clientIdDocumentUrl;
  String clientVerificationStatus = 'not_submitted';

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  Future<void> loadProfile() async {
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .get();
    final data = doc.data() ?? {};

    nameController.text =
        (data['name'] ?? user!.displayName ?? '').toString();
    profilePhotoUrl =
        (data['profilePhotoUrl'] ?? user!.photoURL ?? '').toString();
    clientIdDocumentUrl = (data['clientIdDocumentUrl'] ?? '').toString();
    clientVerificationStatus =
        (data['clientVerificationStatus'] ?? 'not_submitted').toString();

    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> uploadProfilePhoto() async {
    if (user == null) return;

    try {
      setState(() {
        isSaving = true;
      });

      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) {
        throw Exception('No se pudo leer la imagen seleccionada.');
      }

      if (bytes.lengthInBytes > 8 * 1024 * 1024) {
        throw Exception('La imagen debe pesar menos de 8 MB.');
      }

      final extension = (file.extension ?? 'jpg').toLowerCase();
      final ref = FirebaseStorage.instance
          .ref()
          .child('client_photos/${user!.uid}/profile.$extension');

      await ref.putData(
        bytes,
        SettableMetadata(contentType: 'image/$extension'),
      );

      final downloadUrl = await ref.getDownloadURL();
      await FirebaseFirestore.instance.collection('users').doc(user!.uid).set({
        'profilePhotoUrl': downloadUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      setState(() {
        profilePhotoUrl = downloadUrl;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo subir la foto: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  Future<void> uploadClientIdDocument() async {
    if (user == null) return;

    try {
      setState(() {
        isSaving = true;
      });

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) {
        throw Exception('No se pudo leer la imagen seleccionada.');
      }

      if (bytes.lengthInBytes > 8 * 1024 * 1024) {
        throw Exception('La imagen debe pesar menos de 8 MB.');
      }

      final extension = (file.extension ?? 'jpg').toLowerCase();
      final ref = FirebaseStorage.instance
          .ref()
          .child('client_verification/${user!.uid}/id_document.$extension');

      await ref.putData(
        bytes,
        SettableMetadata(contentType: 'image/$extension'),
      );

      final downloadUrl = await ref.getDownloadURL();
      await FirebaseFirestore.instance.collection('users').doc(user!.uid).set({
        'clientIdDocumentUrl': downloadUrl,
        'clientVerificationStatus': 'pending',
        'clientVerificationSubmittedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await FirebaseFirestore.instance.collection('owner_alerts').add({
        'title': 'Documento de cliente para verificacion',
        'message':
            '${nameController.text.trim().isEmpty ? 'Un cliente' : nameController.text.trim()} subio una foto de cedula para revision.',
        'type': 'client_verification',
        'priority': 'medium',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(
          DateTime.now().add(const Duration(days: 60)),
        ),
      });

      setState(() {
        clientIdDocumentUrl = downloadUrl;
        clientVerificationStatus = 'pending';
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto de cedula enviada para revision.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo subir la cedula: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  String clientVerificationLabel() {
    switch (clientVerificationStatus) {
      case 'approved':
        return 'Verificado';
      case 'pending':
        return 'En revision';
      case 'rejected':
        return 'Revisar documento';
      default:
        return 'Opcional';
    }
  }

  Color clientVerificationColor() {
    switch (clientVerificationStatus) {
      case 'approved':
        return const Color(0xFF16A34A);
      case 'pending':
        return const Color(0xFFD97706);
      case 'rejected':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF6B7280);
    }
  }

  Future<void> saveProfile() async {
    if (user == null) return;

    final name = nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe tu nombre')),
      );
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      await FirebaseFirestore.instance.collection('users').doc(user!.uid).set({
        'name': name,
        'role': 'client',
        'profilePhotoUrl': profilePhotoUrl ?? '',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil guardado')),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  Widget buildClientVerificationCard() {
    final statusColor = clientVerificationColor();
    final hasDocument =
        clientIdDocumentUrl != null && clientIdDocumentUrl!.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8DDD1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Verificacion de identidad',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  clientVerificationLabel(),
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Subir una foto de tu cedula es opcional. Nos ayuda a revisar la identidad cuando hay pagos, reclamos o soporte, y protege tanto al cliente como al tecnico durante el servicio.',
            style: TextStyle(
              color: Color(0xFF6D5E4F),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: isSaving ? null : uploadClientIdDocument,
              icon: const Icon(Icons.badge_outlined),
              label: Text(
                !hasDocument
                    ? 'Subir foto de cedula (opcional)'
                    : clientVerificationStatus == 'rejected'
                        ? 'Volver a subir foto de cedula'
                        : 'Actualizar foto de cedula',
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final photoUrl = profilePhotoUrl ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi perfil'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 58,
                  backgroundColor: const Color(0xFFFFEDD8),
                  backgroundImage:
                      photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                  child: photoUrl.isEmpty
                      ? const Icon(
                          Icons.person,
                          size: 52,
                          color: Color(0xFFFF7A00),
                        )
                      : null,
                ),
                FloatingActionButton.small(
                  heroTag: 'client_photo',
                  onPressed: isSaving ? null : uploadProfilePhoto,
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  child: const Icon(Icons.camera_alt),
                ),
              ],
            ),
            const SizedBox(height: 24),
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Nombre visible',
                prefixIcon: const Icon(Icons.person_outline),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
            const SizedBox(height: 20),
            buildClientVerificationCard(),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isSaving ? null : saveProfile,
                icon: const Icon(Icons.save_outlined),
                label: Text(isSaving ? 'Guardando...' : 'Guardar perfil'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
