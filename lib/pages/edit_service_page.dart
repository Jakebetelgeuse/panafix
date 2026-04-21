import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class EditServicePage extends StatefulWidget {
  final String serviceId;
  final String serviceName;
  final double price;

  const EditServicePage({
    super.key,
    required this.serviceId,
    required this.serviceName,
    required this.price,
  });

  @override
  State<EditServicePage> createState() => _EditServicePageState();
}

class _EditServicePageState extends State<EditServicePage> {
  late TextEditingController nameController;
  late TextEditingController priceController;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.serviceName);
    priceController =
        TextEditingController(text: widget.price.toString());
  }

  Future<void> updateService() async {
    final user = FirebaseAuth.instance.currentUser;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('services')
        .doc(widget.serviceId)
        .update({
      'name': nameController.text,
      'price': double.parse(priceController.text),
    });

    Navigator.pop(context);
  }

  Future<void> deleteService() async {
    final user = FirebaseAuth.instance.currentUser;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('services')
        .doc(widget.serviceId)
        .delete();

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar servicio'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Servicio',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Precio',
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: updateService,
              child: const Text('Actualizar'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              onPressed: deleteService,
              child: const Text('Eliminar servicio'),
            )
          ],
        ),
      ),
    );
  }
}