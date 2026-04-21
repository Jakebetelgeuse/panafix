import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'request_service_page.dart';

class TechniciansPage extends StatelessWidget {
  final String category;
  final String service;

  const TechniciansPage({
    super.key,
    required this.category,
    required this.service,
  });

  Future<List<Map<String, dynamic>>> _loadRecentReviews(String technicianId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('reviews')
        .where('technicianId', isEqualTo: technicianId)
        .get();

    final reviews = snapshot.docs.map((doc) => doc.data()).toList()
      ..sort((a, b) {
        final aTime = a['createdAt'] as Timestamp?;
        final bTime = b['createdAt'] as Timestamp?;
        return (bTime?.millisecondsSinceEpoch ?? 0)
            .compareTo(aTime?.millisecondsSinceEpoch ?? 0);
      });

    return reviews.take(2).toList();
  }

  Future<double> _loadServicePrice(String technicianId) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('services')
        .where('technicianId', isEqualTo: technicianId)
        .where('serviceName', isEqualTo: service)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return 0;

    final data = snapshot.docs.first.data();
    final basePrice = (data['basePrice'] as num?)?.toDouble();
    if (basePrice != null && basePrice > 0) {
      return double.parse((basePrice * 1.15).toStringAsFixed(2));
    }
    return (data['priceFrom'] as num?)?.toDouble() ?? 0;
  }

  String _normalizeText(String value) {
    return value
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u');
  }

  bool _listContainsNormalized(List<String> values, String target) {
    final normalizedTarget = _normalizeText(target);
    return values.any((value) => _normalizeText(value) == normalizedTarget);
  }

  bool _isTechAvailableNow(Map<String, dynamic> data) {
    final isAvailable = data['isAvailable'] != false;
    if (!isAvailable) return false;

    final days = List<String>.from(
      data['availableDays'] ?? ['Lun', 'Mar', 'Mie', 'Jue', 'Vie', 'Sab'],
    );

    final now = DateTime.now();
    const weekMap = {
      DateTime.monday: 'Lun',
      DateTime.tuesday: 'Mar',
      DateTime.wednesday: 'Mie',
      DateTime.thursday: 'Jue',
      DateTime.friday: 'Vie',
      DateTime.saturday: 'Sab',
      DateTime.sunday: 'Dom',
    };

    final today = weekMap[now.weekday];
    if (today != null && !days.contains(today)) {
      return false;
    }

    final start = data['workStart']?.toString() ?? '08:00';
    final end = data['workEnd']?.toString() ?? '18:00';
    final startParts = start.split(':');
    final endParts = end.split(':');

    final startMinutes = ((int.tryParse(startParts.first) ?? 8) * 60) +
        (int.tryParse(startParts.last) ?? 0);
    final endMinutes =
        ((int.tryParse(endParts.first) ?? 18) * 60) + (int.tryParse(endParts.last) ?? 0);
    final nowMinutes = (now.hour * 60) + now.minute;

    return nowMinutes >= startMinutes && nowMinutes <= endMinutes;
  }

  String _availabilityLabel(Map<String, dynamic> data) {
    final isEnabled = data['isAvailable'] != false;
    final start = data['workStart']?.toString() ?? '08:00';
    final end = data['workEnd']?.toString() ?? '18:00';
    final days = List<String>.from(
      data['availableDays'] ?? ['Lun', 'Mar', 'Mie', 'Jue', 'Vie', 'Sab'],
    );

    if (!isEnabled) {
      return 'Off temporalmente';
    }

    if (_isTechAvailableNow(data)) {
      return 'Disponible ahora';
    }

    final now = DateTime.now();
    const weekMap = {
      DateTime.monday: 'Lun',
      DateTime.tuesday: 'Mar',
      DateTime.wednesday: 'Mie',
      DateTime.thursday: 'Jue',
      DateTime.friday: 'Vie',
      DateTime.saturday: 'Sab',
      DateTime.sunday: 'Dom',
    };
    const orderedDays = ['Lun', 'Mar', 'Mie', 'Jue', 'Vie', 'Sab', 'Dom'];

    final today = weekMap[now.weekday] ?? 'Lun';
    final startParts = start.split(':');
    final endParts = end.split(':');
    final startMinutes = ((int.tryParse(startParts.first) ?? 8) * 60) +
        (int.tryParse(startParts.last) ?? 0);
    final endMinutes = ((int.tryParse(endParts.first) ?? 18) * 60) +
        (int.tryParse(endParts.last) ?? 0);
    final nowMinutes = (now.hour * 60) + now.minute;

    if (days.contains(today) && nowMinutes < startMinutes) {
      return 'Off hasta $start';
    }

    if (days.contains(today) && nowMinutes > endMinutes) {
      for (var offset = 1; offset <= 7; offset++) {
        final day = orderedDays[(orderedDays.indexOf(today) + offset) % 7];
        if (days.contains(day)) {
          return 'Off hasta $day $start';
        }
      }
    }

    for (var offset = 0; offset < 7; offset++) {
      final day = orderedDays[(orderedDays.indexOf(today) + offset) % 7];
      if (day != today && days.contains(day)) {
        return 'Off hasta $day $start';
      }
    }

    return 'Off por horario';
  }

  String _scheduleLabel(Map<String, dynamic> data) {
    final start = data['workStart']?.toString() ?? '08:00';
    final end = data['workEnd']?.toString() ?? '18:00';
    return '$start - $end';
  }

  bool _hasActivePromotion(Map<String, dynamic> data) {
    final status = (data['subscriptionStatus'] ?? '').toString();
    if (status != 'active') return false;

    final promotedUntil = data['promotedUntil'] as Timestamp?;
    if (promotedUntil == null) return false;

    return promotedUntil.toDate().isAfter(DateTime.now());
  }

  int _promotionPriority(Map<String, dynamic> data) {
    if (!_hasActivePromotion(data)) return 0;
    return (data['subscriptionPriority'] as num?)?.toInt() ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(service),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF0F172A),
                      Color(0xFF1D4ED8),
                      Color(0xFF60A5FA),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tecnicos recomendados',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Mostrando perfiles para $service en $category, incluyendo tecnicos fuera de horario.',
                      style: const TextStyle(
                        color: Color(0xFFDBEAFE),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .where('role', isEqualTo: 'technician')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'No se pudieron cargar los tecnicos: ${snapshot.error}',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }

                  final technicians = snapshot.data?.docs ?? [];

                  final filteredTechs = technicians.where((doc) {
                    final data = doc.data();
                    final categories = List<String>.from(data['categories'] ?? []);
                    final services = List<String>.from(data['services'] ?? []);
                    final matchesCategory =
                        _listContainsNormalized(categories, category);
                    final matchesService =
                        _listContainsNormalized(services, service);

                    return matchesCategory && matchesService;
                  }).toList()
                    ..sort((a, b) {
                      final aData = a.data();
                      final bData = b.data();

                      final priorityCompare = _promotionPriority(bData)
                          .compareTo(_promotionPriority(aData));
                      if (priorityCompare != 0) return priorityCompare;

                      final ratingCompare = ((bData['rating'] as num?)?.toDouble() ?? 0)
                          .compareTo((aData['rating'] as num?)?.toDouble() ?? 0);
                      if (ratingCompare != 0) return ratingCompare;

                      final availabilityCompare =
                          (_isTechAvailableNow(bData) ? 1 : 0)
                              .compareTo(_isTechAvailableNow(aData) ? 1 : 0);
                      if (availabilityCompare != 0) return availabilityCompare;

                      return ((bData['reviewsCount'] as num?)?.toInt() ?? 0)
                          .compareTo((aData['reviewsCount'] as num?)?.toInt() ?? 0);
                    });

                  if (filteredTechs.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 88,
                              height: 88,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFEDD8),
                                borderRadius: BorderRadius.circular(28),
                              ),
                              child: const Icon(
                                Icons.search_off_rounded,
                                size: 42,
                                color: Color(0xFFFF7A00),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No encontramos tecnicos para este servicio',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Todavia no hay perfiles registrados para $service en $category.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFF756B61),
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredTechs.length,
                    itemBuilder: (context, index) {
                      final doc = filteredTechs[index];
                      final tech = doc.data();

                      final name = tech['name']?.toString() ?? 'Tecnico';
                      final city = tech['city']?.toString() ?? 'Cerca de ti';
                      final profilePhotoUrl =
                          tech['profilePhotoUrl']?.toString() ?? '';
                      final hasPromotion = _hasActivePromotion(tech);
                      final subscriptionPlan =
                          (tech['subscriptionPlan'] ?? '').toString();
                      final ratingNum =
                          (tech['rating'] as num?)?.toDouble() ?? 5.0;
                      final reviewsCount =
                          (tech['reviewsCount'] as num?)?.toInt() ?? 0;
                      final bio = tech['bio']?.toString().trim() ?? '';
                      final verificationStatus =
                          (tech['verificationStatus'] ?? 'not_submitted')
                              .toString();
                      final availabilityLabel = _availabilityLabel(tech);
                      final isAvailableNow = _isTechAvailableNow(tech);
                      final yearsExperience =
                          (tech['yearsExperience'] as num?)?.toInt() ?? 1;
                      final serviceRadius =
                          (tech['serviceRadius'] as num?)?.toInt() ?? 10;
                      final technicianUid = tech['uid']?.toString() ??
                          tech['userId']?.toString() ??
                          doc.id;

                      return FutureBuilder<double>(
                        future: _loadServicePrice(technicianUid),
                        builder: (context, priceSnapshot) {
                          final price = priceSnapshot.data ?? 0;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 14),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 22,
                                  offset: const Offset(0, 16),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 60,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        gradient: profilePhotoUrl.isEmpty
                                            ? const LinearGradient(
                                                colors: [
                                                  Color(0xFFFF9A3D),
                                                  Color(0xFFFFC56A),
                                                ],
                                              )
                                            : null,
                                        color: profilePhotoUrl.isEmpty
                                            ? null
                                            : const Color(0xFFFFF4DB),
                                        borderRadius: BorderRadius.circular(20),
                                        image: profilePhotoUrl.isNotEmpty
                                            ? DecorationImage(
                                                image:
                                                    NetworkImage(profilePhotoUrl),
                                                fit: BoxFit.cover,
                                              )
                                            : null,
                                      ),
                                      child: profilePhotoUrl.isEmpty
                                          ? const Icon(
                                              Icons.person,
                                              color: Colors.white,
                                              size: 32,
                                            )
                                          : null,
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            name,
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          if (hasPromotion) ...[
                                            const SizedBox(height: 6),
                                            _MiniPill(
                                              label: subscriptionPlan == 'premium'
                                                  ? 'Patrocinado Premium'
                                                  : 'Destacado Pro',
                                              backgroundColor: subscriptionPlan == 'premium'
                                                  ? const Color(0xFFFFEDD8)
                                                  : const Color(0xFFEAFBF0),
                                              foregroundColor: subscriptionPlan == 'premium'
                                                  ? const Color(0xFFB45309)
                                                  : const Color(0xFF0F766E),
                                            ),
                                          ],
                                          const SizedBox(height: 6),
                                          Text(
                                            '$city  |  Horario ${_scheduleLabel(tech)}',
                                            style: const TextStyle(
                                              color: Color(0xFF756B61),
                                              height: 1.35,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: [
                                              _MiniPill(
                                                label:
                                                    '${ratingNum.toStringAsFixed(1)} estrellas',
                                                backgroundColor:
                                                    const Color(0xFFFFEDD8),
                                                foregroundColor:
                                                    const Color(0xFFFF7A00),
                                              ),
                                              if (verificationStatus ==
                                                  'approved')
                                                const _MiniPill(
                                                  label: 'Verificado',
                                                  backgroundColor:
                                                      Color(0xFFEAFBF0),
                                                  foregroundColor:
                                                      Color(0xFF16A34A),
                                                ),
                                              _MiniPill(
                                                label: '$reviewsCount resenas',
                                                backgroundColor:
                                                    const Color(0xFFEAF3FF),
                                                foregroundColor:
                                                    const Color(0xFF2563EB),
                                              ),
                                              _MiniPill(
                                                label: availabilityLabel,
                                                backgroundColor: isAvailableNow
                                                    ? const Color(0xFFEAFBF0)
                                                    : const Color(0xFFFFF1E6),
                                                foregroundColor: isAvailableNow
                                                    ? const Color(0xFF16A34A)
                                                    : const Color(0xFFB45309),
                                              ),
                                              _MiniPill(
                                                label:
                                                    '$yearsExperience anos exp.',
                                                backgroundColor:
                                                    const Color(0xFFF3E8FF),
                                                foregroundColor:
                                                    const Color(0xFF7C3AED),
                                              ),
                                              _MiniPill(
                                                label:
                                                    '${serviceRadius} km de cobertura',
                                                backgroundColor:
                                                    const Color(0xFFFFF4DB),
                                                foregroundColor:
                                                    const Color(0xFFB45309),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                if (bio.isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF9FAFB),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      bio,
                                      style: const TextStyle(
                                        color: Color(0xFF3B3129),
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 14),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF7F4EF),
                                    borderRadius: BorderRadius.circular(22),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.sell_outlined,
                                        color: Color(0xFFFF7A00),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        'Desde \$${price.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (reviewsCount > 0) ...[
                                  const SizedBox(height: 12),
                                  FutureBuilder<List<Map<String, dynamic>>>(
                                    future: _loadRecentReviews(technicianUid),
                                    builder: (context, reviewSnapshot) {
                                      if (!reviewSnapshot.hasData ||
                                          reviewSnapshot.data!.isEmpty) {
                                        return const SizedBox();
                                      }

                                      final reviews = reviewSnapshot.data!;

                                      return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Comentarios recientes',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          ...reviews.map((review) {
                                            final reviewText = review['review']
                                                    ?.toString()
                                                    .trim() ??
                                                '';
                                            final reviewRating =
                                                (review['rating'] as num?)
                                                        ?.toDouble() ??
                                                    5.0;

                                            if (reviewText.isEmpty) {
                                              return const SizedBox();
                                            }

                                            return Container(
                                              width: double.infinity,
                                              margin:
                                                  const EdgeInsets.only(bottom: 8),
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF9FAFB),
                                                borderRadius:
                                                    BorderRadius.circular(18),
                                              ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    '${reviewRating.toStringAsFixed(1)} estrellas',
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    reviewText,
                                                    style: const TextStyle(
                                                      color: Color(0xFF3B3129),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }),
                                        ],
                                      );
                                    },
                                  ),
                                ],
                                const SizedBox(height: 14),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: price <= 0
                                        ? null
                                        : () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    RequestServicePage(
                                                  technicianId: technicianUid,
                                                  technicianName: name,
                                                  category: category,
                                                  service: service,
                                                  city: city,
                                                  priceFrom: price,
                                                ),
                                              ),
                                            );
                                          },
                                    child: Text(
                                      price <= 0
                                          ? 'Sin precio configurado'
                                          : 'Solicitar servicio',
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
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniPill extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  const _MiniPill({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foregroundColor,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
