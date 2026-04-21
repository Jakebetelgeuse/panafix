import 'package:cloud_firestore/cloud_firestore.dart';

class OwnerAlertService {
  OwnerAlertService._();

  static Future<void> createAlert({
    required String title,
    required String message,
    required String type,
    String? orderId,
    String priority = 'normal',
  }) async {
    await FirebaseFirestore.instance.collection('owner_alerts').add({
      'title': title,
      'message': message,
      'type': type,
      'orderId': orderId ?? '',
      'priority': priority,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(
        DateTime.now().add(const Duration(days: 60)),
      ),
    });
  }
}
