import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class OrderChatPage extends StatefulWidget {
  final String orderId;
  final String otherUserId;
  final String otherUserName;
  final String serviceName;

  const OrderChatPage({
    super.key,
    required this.orderId,
    required this.otherUserId,
    required this.otherUserName,
    required this.serviceName,
  });

  @override
  State<OrderChatPage> createState() => _OrderChatPageState();
}

class _OrderChatPageState extends State<OrderChatPage> {
  final TextEditingController messageController = TextEditingController();
  final User? currentUser = FirebaseAuth.instance.currentUser;
  bool isSending = false;

  @override
  void dispose() {
    messageController.dispose();
    super.dispose();
  }

  Future<void> sendMessage() async {
    final text = messageController.text.trim();
    if (text.isEmpty || currentUser == null) return;

    final orderDoc = await FirebaseFirestore.instance
        .collection('orders')
        .doc(widget.orderId)
        .get();
    final orderData = orderDoc.data() ?? {};
    final orderStatus = (orderData['status'] ?? '').toString();

    if (orderStatus != 'on_the_way') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'El chat solo esta disponible mientras el tecnico va en camino.',
          ),
        ),
      );
      return;
    }

    setState(() {
      isSending = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .collection('messages')
          .add({
        'senderId': currentUser!.uid,
        'senderName': currentUser!.displayName ?? 'Usuario',
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': widget.otherUserId,
        'title': 'Nuevo mensaje',
        'message': 'Tienes un nuevo mensaje en "${widget.serviceName}".',
        'type': 'chat',
        'isRead': false,
        'orderId': widget.orderId,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(
          DateTime.now().add(const Duration(days: 30)),
        ),
      });

      messageController.clear();
    } finally {
      if (mounted) {
        setState(() {
          isSending = false;
        });
      }
    }
  }

  Widget _avatar(String? photoUrl, String name) {
    if (photoUrl != null && photoUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 22,
        backgroundImage: NetworkImage(photoUrl),
      );
    }

    return CircleAvatar(
      radius: 22,
      backgroundColor: const Color(0xFFFFEDD8),
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: const TextStyle(
          color: Color(0xFFFF7A00),
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .snapshots(),
      builder: (context, orderSnapshot) {
        if (orderSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final orderData = orderSnapshot.data?.data() ?? {};
        final orderStatus = (orderData['status'] ?? '').toString();
        final chatEnabled = orderStatus == 'on_the_way';

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(widget.otherUserId)
              .snapshots(),
          builder: (context, userSnapshot) {
            final otherUserData = userSnapshot.data?.data();
            final otherPhotoUrl =
                otherUserData?['profilePhotoUrl']?.toString() ?? '';

            return Scaffold(
              backgroundColor: const Color(0xFFF6F7FB),
              appBar: AppBar(
                title: Row(
                  children: [
                    _avatar(otherPhotoUrl, widget.otherUserName),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.otherUserName),
                          Text(
                            widget.serviceName,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF756B61),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              body: Column(
                children: [
                  if (!chatEnabled)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF4E8),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFFFD2A8)),
                      ),
                      child: const Text(
                        'El chat solo esta disponible mientras el tecnico va en camino. Cuando llega al lugar, el chat se cierra.',
                        style: TextStyle(
                          color: Color(0xFF8A4700),
                          fontWeight: FontWeight.w700,
                          height: 1.4,
                        ),
                      ),
                    ),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('orders')
                          .doc(widget.orderId)
                          .collection('messages')
                          .orderBy('createdAt')
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        final docs = snapshot.data?.docs ?? [];

                        if (docs.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                chatEnabled
                                    ? 'Todavia no hay mensajes. Si hace falta, coordina mientras el tecnico va en camino.'
                                    : 'No hay mensajes disponibles para este servicio.',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          );
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: docs.length,
                          itemBuilder: (context, index) {
                            final message = docs[index].data();
                            final senderId =
                                (message['senderId'] ?? '').toString();
                            final text = (message['text'] ?? '').toString();
                            final isMine = senderId == currentUser?.uid;

                            return Align(
                              alignment: isMine
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                constraints:
                                    const BoxConstraints(maxWidth: 280),
                                decoration: BoxDecoration(
                                  color: isMine ? Colors.orange : Colors.white,
                                  borderRadius: BorderRadius.circular(18),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  text,
                                  style: TextStyle(
                                    color: isMine
                                        ? Colors.white
                                        : Colors.black87,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  if (chatEnabled)
                    SafeArea(
                      top: false,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          border: Border(
                            top: BorderSide(color: Color(0xFFEAEAEA)),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: messageController,
                                minLines: 1,
                                maxLines: 4,
                                decoration: InputDecoration(
                                  hintText: 'Escribe un mensaje...',
                                  filled: true,
                                  fillColor: const Color(0xFFF5F5F5),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(18),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            FilledButton(
                              onPressed: isSending ? null : sendMessage,
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.orange,
                                padding: const EdgeInsets.all(16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: isSending
                                  ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.send),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
