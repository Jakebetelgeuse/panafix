import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'my_requests_page.dart';
import 'services_page.dart';
import 'notifications_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  void openCategory(BuildContext context, String category) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ServicesPage(category: category),
      ),
    );
  }

  Widget categoryCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return GestureDetector(
      onTap: () => openCategory(context, title),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: color.withValues(alpha: 0.15),
                child: Icon(icon, color: color, size: 28),
              ),
              const Spacer(),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 13,
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
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        title: const Text('Panafix'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const NotificationsPage(),
                ),
              );
            },
            icon: const Icon(Icons.notifications),
          ),
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const MyRequestsPage(),
                ),
              );
            },
            icon: const Icon(Icons.receipt_long),
          ),
          IconButton(
            onPressed: signOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF8C1A), Color(0xFFFFA94D)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(26),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '¿Qué necesitas reparar hoy?',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Encuentra técnicos confiables según el tipo de servicio que necesites.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              elevation: 2,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.orange.withValues(alpha: 0.15),
                  child: const Icon(
                    Icons.receipt_long,
                    color: Colors.orange,
                  ),
                ),
                title: const Text(
                  'Mis solicitudes',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: const Text('Revisa el estado de tus servicios'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 18),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const MyRequestsPage(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'Categorías',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 0.95,
                children: [
                  categoryCard(
                    context,
                    title: 'Electricidad',
                    subtitle: 'Lámparas, cableado y más',
                    icon: Icons.flash_on,
                    color: Colors.orange,
                  ),
                  categoryCard(
                    context,
                    title: 'Fontanería',
                    subtitle: 'Tuberías, fugas y grifos',
                    icon: Icons.plumbing,
                    color: Colors.blue,
                  ),
                  categoryCard(
                    context,
                    title: 'Cerrajería',
                    subtitle: 'Puertas, llaves y cerraduras',
                    icon: Icons.key,
                    color: Colors.amber,
                  ),
                  categoryCard(
                    context,
                    title: 'Internet/TV',
                    subtitle: 'Router, WiFi e instalación',
                    icon: Icons.router,
                    color: Colors.purple,
                  ),
                  categoryCard(
                    context,
                    title: 'Electrodomésticos',
                    subtitle: 'Nevera, lavadora y cocina',
                    icon: Icons.kitchen,
                    color: Colors.green,
                  ),
                  categoryCard(
                    context,
                    title: 'Más servicios',
                    subtitle: 'Pintura, soldadura y más',
                    icon: Icons.build,
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}