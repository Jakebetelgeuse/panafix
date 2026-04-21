import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:firebase_storage/firebase_storage.dart';

class PaymentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<String?> pickAndUploadProof(String orderId) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      return null;
    }

    final file = result.files.first;
    final Uint8List? bytes = file.bytes;

    if (bytes == null) {
      throw Exception('No se pudo leer el archivo');
    }

    final sizeInBytes = bytes.lengthInBytes;
    const maxSizeInBytes = 8 * 1024 * 1024;
    if (sizeInBytes > maxSizeInBytes) {
      throw Exception('La imagen es muy pesada. Usa una menor de 8 MB.');
    }

    final extension = file.extension ?? 'jpg';
    final fileName =
        'proof_${DateTime.now().millisecondsSinceEpoch}.$extension';

    final ref = _storage.ref().child('payment_proofs/$orderId/$fileName');

    try {
      final uploadTask = await ref
          .putData(
            bytes,
            SettableMetadata(
              contentType: 'image/$extension',
            ),
          )
          .timeout(const Duration(seconds: 45));

      return uploadTask.ref.getDownloadURL();
    } on firebase_storage.FirebaseException catch (e) {
      throw Exception('Storage fallo (${e.code}): ${e.message ?? 'sin detalle'}');
    } on TimeoutException {
      throw Exception(
        'La subida tardo demasiado. Revisa tu conexion e intenta con una imagen mas liviana.',
      );
    }
  }

  Future<void> submitPaymentProof({
    required String orderId,
    required String proofUrl,
    required String paymentMethod,
    required String reference,
    required double amount,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('Usuario no autenticado');
    }

    final retainUntil = DateTime.now().add(const Duration(days: 14));

    await _firestore.collection('orders').doc(orderId).set({
      'paymentMethod': paymentMethod,
      'paymentReference': reference,
      'paymentAmount': amount,
      'paymentProofUrl': proofUrl,
      'paymentUploadedBy': user.uid,
      'paymentUploadedAt': FieldValue.serverTimestamp(),
      'paymentRetainUntil': Timestamp.fromDate(retainUntil),
      'paymentRetentionDays': 14,
      'paymentStatus': 'paid',
      'status': 'pending',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
