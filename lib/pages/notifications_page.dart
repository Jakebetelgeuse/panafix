import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final User? user = FirebaseAuth.instance.currentUser;

  Future<String> _collectionName() async {
    if (user == null) return 'notifications';

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .get();
    final role = userDoc.data()?['role']?.toString() ?? 'client';
    return role == 'owner' ? 'owner_alerts' : 'notifications';
  }

  Future<bool> _isOwnerRole() async {
    if (user == null) return false;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .get();
    final role = userDoc.data()?['role']?.toString() ?? 'client';
    return role == 'owner';
  }

  Future<void> markAllAsRead() async {
    if (user == null) return;

    final collectionName = await _collectionName();
    final isOwner = await _isOwnerRole();

    Query<Map<String, dynamic>> query =
        FirebaseFirestore.instance.collection(collectionName);
    if (!isOwner) {
      query = query.where('userId', isEqualTo: user!.uid);
    }

    final docs = await query.get();
    final batch = FirebaseFirestore.instance.batch();

    for (final doc in docs.docs.where((doc) => doc.data()['isRead'] != true)) {
      batch.update(doc.reference, {
        'isRead': true,
        'readAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  Future<void> deleteNotification(String notificationId) async {
    final collectionName = await _collectionName();
    await FirebaseFirestore.instance
        .collection(collectionName)
        .doc(notificationId)
        .delete();
  }

  Future<void> deleteReadNotifications() async {
    if (user == null) return;

    final collectionName = await _collectionName();
    final isOwner = await _isOwnerRole();

    Query<Map<String, dynamic>> query =
        FirebaseFirestore.instance.collection(collectionName);
    if (!isOwner) {
      query = query.where('userId', isEqualTo: user!.uid);
    }

    final docs = await query.get();
    final batch = FirebaseFirestore.instance.batch();

    for (final doc in docs.docs.where((doc) => doc.data()['isRead'] == true)) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }

  Future<void> markAsRead(String notificationId) async {
    if (user == null) return;

    final collectionName = await _collectionName();
    await FirebaseFirestore.instance
        .collection(collectionName)
        .doc(notificationId)
        .update({
      'isRead': true,
      'readAt': FieldValue.serverTimestamp(),
    });
  }

  String formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'Ahora mismo';

    final date = timestamp.toDate().toLocal();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) return 'Hace un momento';
    if (difference.inHours < 1) return 'Hace ${difference.inMinutes} min';
    if (difference.inDays < 1) return 'Hace ${difference.inHours} h';
    if (difference.inDays < 7) return 'Hace ${difference.inDays} d';

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  String formatExactTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'Sin fecha exacta';
    final date = timestamp.toDate().toLocal();
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year} ${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  IconData resolveIcon(String? type) {
    switch (type) {
      case 'request':
        return Icons.assignment;
      case 'job':
        return Icons.build_circle;
      case 'review':
        return Icons.star;
      case 'payment':
        return Icons.payments;
      case 'emergency':
        return Icons.warning_amber_rounded;
      default:
        return Icons.notifications;
    }
  }

  Color resolveIconColor(String? type) {
    switch (type) {
      case 'request':
        return Colors.orange;
      case 'job':
        return Colors.blue;
      case 'review':
        return Colors.amber.shade700;
      case 'payment':
        return Colors.green;
      case 'emergency':
        return Colors.red;
      default:
        return Colors.deepOrange;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Notificaciones'),
        ),
        body: const Center(
          child: Text('Debes iniciar sesion para ver tus notificaciones.'),
        ),
      );
    }

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance.collection('users').doc(user!.uid).get(),
      builder: (context, userSnapshot) {
        if (!userSnapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final role = userSnapshot.data!.data()?['role']?.toString() ?? 'client';
        final isOwner = role == 'owner';
        final stream = isOwner
            ? FirebaseFirestore.instance.collection('owner_alerts').snapshots()
            : FirebaseFirestore.instance
                .collection('notifications')
                .where('userId', isEqualTo: user!.uid)
                .snapshots();

        return Scaffold(
          backgroundColor: const Color(0xFFF7F7F7),
          appBar: AppBar(
            title: Text(isOwner ? 'Alertas de duena' : 'Notificaciones'),
            actions: [
              TextButton(
                onPressed: markAllAsRead,
                child: const Text(
                  'Marcar todas',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'delete_read') {
                    deleteReadNotifications();
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'delete_read',
                    child: Text('Borrar leidas'),
                  ),
                ],
              ),
            ],
          ),
          body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: stream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'No se pudieron cargar las notificaciones.\n${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = [...?snapshot.data?.docs]
                ..sort((a, b) {
                  final aTimestamp = a.data()['createdAt'] as Timestamp?;
                  final bTimestamp = b.data()['createdAt'] as Timestamp?;
                  final aMillis = aTimestamp?.millisecondsSinceEpoch ?? 0;
                  final bMillis = bTimestamp?.millisecondsSinceEpoch ?? 0;
                  return bMillis.compareTo(aMillis);
                });

              if (docs.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.notifications_none,
                          size: 72,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          isOwner
                              ? 'Todavia no tienes alertas de duena.'
                              : 'Todavia no tienes notificaciones.',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Aqui apareceran avisos importantes de la operacion y de la plataforma.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data();

                  final title = data['title']?.toString() ?? 'Notificacion';
                  final message = data['message']?.toString() ?? '';
                  final type = data['type']?.toString();
                  final isRead = data['isRead'] == true;
                  final createdAt = data['createdAt'] as Timestamp?;
                  final iconColor = resolveIconColor(type);

                  return Dismissible(
                    key: ValueKey(doc.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    onDismissed: (_) => deleteNotification(doc.id),
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      elevation: isRead ? 1 : 3,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {
                          if (!isRead) {
                            markAsRead(doc.id);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isRead
                                  ? Colors.transparent
                                  : Colors.orange.withValues(alpha: 0.35),
                              width: 1.3,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor:
                                    iconColor.withValues(alpha: 0.12),
                                child: Icon(
                                  resolveIcon(type),
                                  color: iconColor,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            title,
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: isRead
                                                  ? FontWeight.w600
                                                  : FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                        if (!isRead)
                                          Container(
                                            width: 10,
                                            height: 10,
                                            decoration: const BoxDecoration(
                                              color: Colors.orange,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      message.isEmpty
                                          ? 'Tienes una nueva actualizacion.'
                                          : message,
                                      style: const TextStyle(
                                        color: Colors.black87,
                                        height: 1.35,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      '${formatTimestamp(createdAt)} | ${formatExactTimestamp(createdAt)}',
                                      style: const TextStyle(
                                        color: Colors.black54,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton.icon(
                                        onPressed: () =>
                                            deleteNotification(doc.id),
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          size: 18,
                                        ),
                                        label: const Text('Borrar'),
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
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}
