import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class RateClientPage extends StatefulWidget {
  final String orderId;
  final String clientId;
  final String clientName;
  final String? clientPhotoUrl;
  final String serviceName;

  const RateClientPage({
    super.key,
    required this.orderId,
    required this.clientId,
    required this.clientName,
    required this.serviceName,
    this.clientPhotoUrl,
  });

  @override
  State<RateClientPage> createState() => _RateClientPageState();
}

class _RateClientPageState extends State<RateClientPage> {
  final TextEditingController commentController = TextEditingController();
  bool wasGoodClient = true;
  bool matchedPhoto = true;
  bool isSaving = false;

  @override
  void dispose() {
    commentController.dispose();
    super.dispose();
  }

  Widget _avatar() {
    final photoUrl = widget.clientPhotoUrl ?? '';
    if (photoUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 42,
        backgroundImage: NetworkImage(photoUrl),
      );
    }

    return CircleAvatar(
      radius: 42,
      backgroundColor: const Color(0xFFFFEDD8),
      child: Text(
        widget.clientName.isNotEmpty ? widget.clientName[0].toUpperCase() : '?',
        style: const TextStyle(
          color: Color(0xFFFF7A00),
          fontSize: 32,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Future<void> submitReview() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      isSaving = true;
    });

    try {
      final firestore = FirebaseFirestore.instance;

      await firestore.collection('client_reviews').add({
        'orderId': widget.orderId,
        'clientId': widget.clientId,
        'clientName': widget.clientName,
        'clientPhotoUrl': widget.clientPhotoUrl ?? '',
        'technicianId': user.uid,
        'serviceName': widget.serviceName,
        'wasGoodClient': wasGoodClient,
        'matchedPhoto': matchedPhoto,
        'comment': commentController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      await firestore.collection('orders').doc(widget.orderId).set({
        'clientReviewedByTechnician': true,
        'clientWasGood': wasGoodClient,
        'clientMatchedPhoto': matchedPhoto,
        'clientReviewComment': commentController.text.trim(),
        'clientReviewedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await firestore.collection('users').doc(widget.clientId).set({
        'lastClientReviewAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Evaluacion del cliente guardada')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar: $e')),
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
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7ED),
      appBar: AppBar(
        title: const Text('Evaluar cliente'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 22,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _avatar(),
                  const SizedBox(height: 12),
                  Text(
                    widget.clientName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.serviceName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SwitchListTile(
              value: wasGoodClient,
              activeColor: Colors.orange,
              title: const Text(
                'Fue un buen cliente',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: const Text(
                'Respeto el acuerdo, trato bien y facilito el trabajo.',
              ),
              onChanged: (value) {
                setState(() {
                  wasGoodClient = value;
                });
              },
            ),
            SwitchListTile(
              value: matchedPhoto,
              activeColor: Colors.orange,
              title: const Text(
                'Era la persona de la foto',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: const Text(
                'Confirma si quien te atendio coincide con el perfil mostrado.',
              ),
              onChanged: (value) {
                setState(() {
                  matchedPhoto = value;
                });
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: commentController,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Comentario opcional',
                hintText: 'Ej: Fue amable, estaba en la direccion, todo bien.',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isSaving ? null : submitReview,
                icon: isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.verified_user_outlined),
                label: Text(isSaving ? 'Guardando...' : 'Guardar evaluacion'),
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
