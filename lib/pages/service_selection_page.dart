import 'package:flutter/material.dart';
import '../models/technician.dart';
import 'request_page.dart';

class ServiceSelectionPage extends StatelessWidget {
  final String categoryName;
  final Technician technician;

  const ServiceSelectionPage({
    super.key,
    required this.categoryName,
    required this.technician,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(technician.name),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Selecciona el servicio',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Categoría: $categoryName',
              style: const TextStyle(
                color: Colors.black54,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 18),
            Expanded(
              child: ListView.builder(
                itemCount: technician.services.length,
                itemBuilder: (context, index) {
                  final service = technician.services[index];

                  return Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.grey.shade300),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFEDD5),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            service.icon,
                            color: const Color(0xFFFF7A00),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                service.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '\$${service.price.toStringAsFixed(0)}',
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: Color(0xFFFF7A00),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF7A00),
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => RequestPage(
                                  technicianId: technician.id,
                                  serviceName: service.name,
                                  technicianName: technician.name,
                                  priceFrom: service.price,
                                  categoryName: categoryName,
                                ),
                              ),
                            );
                          },
                          child: const Text('Elegir'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
