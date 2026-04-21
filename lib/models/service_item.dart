import 'package:flutter/material.dart';

class ServiceItem {
  final String id;
  final String name;
  final double price;
  final IconData icon;

  const ServiceItem({
    required this.id,
    required this.name,
    required this.price,
    required this.icon,
  });
}