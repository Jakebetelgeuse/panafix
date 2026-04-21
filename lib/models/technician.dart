import 'service_item.dart';

class Technician {
  final String id;
  final String name;
  final double rating;
  final String category;
  final List<ServiceItem> services;

  Technician({
    required this.id,
    required this.name,
    required this.rating,
    required this.category,
    required this.services,
  });
}
