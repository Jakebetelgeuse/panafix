import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class RateTechnicianPage extends StatefulWidget {
  final String orderId;
  final String technicianId;
  final String technicianName;
  final String? technicianPhotoUrl;

  const RateTechnicianPage({
    super.key,
    required this.orderId,
    required this.technicianId,
    required this.technicianName,
    this.technicianPhotoUrl,
  });

  @override
  State<RateTechnicianPage> createState() => _RateTechnicianPageState();
}

class _RateTechnicianPageState extends State<RateTechnicianPage> {
  final TextEditingController reviewController = TextEditingController();
  final currentUser = FirebaseAuth.instance.currentUser;
  int selectedRating = 5;
  bool isSaving = false;

  Widget _avatar() {
    if (widget.technicianPhotoUrl != null &&
        widget.technicianPhotoUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 34,
        backgroundImage: NetworkImage(widget.technicianPhotoUrl!),
      );
    }

    return CircleAvatar(
      radius: 34,
      backgroundColor: const Color(0xFFFFEDD8),
      child: Text(
        widget.technicianName.isNotEmpty
            ? widget.technicianName[0].toUpperCase()
            : '?',
        style: const TextStyle(
          color: Color(0xFFFF7A00),
          fontSize: 26,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Future<void> submitRating() async {
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes iniciar sesion para calificar.')),
      );
      return;
    }

    setState(() {
      isSaving = true;
    });

    final firestore = FirebaseFirestore.instance;

    await firestore.collection('reviews').add({
      'orderId': widget.orderId,
      'clientId': currentUser!.uid,
      'technicianId': widget.technicianId,
      'technicianName': widget.technicianName,
      'rating': selectedRating,
      'review': reviewController.text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    await firestore.collection('orders').doc(widget.orderId).update({
      'reviewed': true,
      'rating': selectedRating,
      'review': reviewController.text.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final reviewsSnapshot = await firestore
        .collection('reviews')
        .where('technicianId', isEqualTo: widget.technicianId)
        .get();

    double average = 0;
    if (reviewsSnapshot.docs.isNotEmpty) {
      double total = 0;
      for (final doc in reviewsSnapshot.docs) {
        final data = doc.data();
        final ratingValue = data['rating'];
        if (ratingValue is num) {
          total += ratingValue.toDouble();
        }
      }
      average = total / reviewsSnapshot.docs.length;
    }

    await firestore.collection('users').doc(widget.technicianId).set({
      'rating': average,
      'reviewsCount': reviewsSnapshot.docs.length,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await firestore.collection('notifications').add({
      'userId': widget.technicianId,
      'title': 'Nueva resena',
      'message': 'Recibiste una nueva calificacion de $selectedRating estrellas.',
      'type': 'review',
      'orderId': widget.orderId,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(
        DateTime.now().add(const Duration(days: 30)),
      ),
    });

    setState(() {
      isSaving = false;
    });

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Calificacion enviada')),
    );

    Navigator.pop(context);
  }

  Widget starButton(int value) {
    final isSelected = value <= selectedRating;
    return IconButton(
      onPressed: () {
        setState(() {
          selectedRating = value;
        });
      },
      icon: Icon(
        isSelected ? Icons.star : Icons.star_border,
        color: Colors.orange,
        size: 34,
      ),
    );
  }

  @override
  void dispose() {
    reviewController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        title: const Text('Calificar tecnico'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Material(
              color: Colors.white,
              elevation: 2,
              borderRadius: BorderRadius.circular(22),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    _avatar(),
                    const SizedBox(height: 12),
                    Text(
                      widget.technicianName,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '¿Como fue tu experiencia?',
                      style: TextStyle(
                        color: Colors.black54,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        starButton(1),
                        starButton(2),
                        starButton(3),
                        starButton(4),
                        starButton(5),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Material(
              color: Colors.white,
              elevation: 2,
              borderRadius: BorderRadius.circular(22),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Comentario',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: reviewController,
                      maxLines: 5,
                      decoration: InputDecoration(
                        hintText: 'Cuentanos como fue el servicio...',
                        filled: true,
                        fillColor: const Color(0xFFF7F7F7),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isSaving ? null : submitRating,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: isSaving
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Text(
                        'Enviar calificacion',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
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
