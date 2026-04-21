import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

class BcvRate {
  final double rate;
  final String source;
  final String rateDate;
  final bool fromInternet;

  const BcvRate({
    required this.rate,
    required this.source,
    required this.rateDate,
    required this.fromInternet,
  });

  bool get isAvailable => rate > 0;

  double usdToVes(double amountUsd) {
    return double.parse((amountUsd * rate).toStringAsFixed(2));
  }
}

class BcvRateService {
  BcvRateService._();

  static final _doc =
      FirebaseFirestore.instance.collection('app_config').doc('bcv_rate');

  static const String defaultApiUrl =
      'https://ve.dolarapi.com/v1/dolares/oficial';

  static const List<String> fallbackApiUrls = [
    'https://ve.dolarapi.com/v1/dolares/oficial',
    'https://bcvapi.tech/api/v1/dolar',
    'https://pydolarve.org/api/v1/dollar?page=bcv',
  ];

  static Future<BcvRate> getRate({
    bool forceRefresh = false,
    bool persistOnlineRate = false,
  }) async {
    final config = await _readConfig();

    if (forceRefresh) {
      final onlineRate = await _fetchOnlineRateWithFallbacks(
        apiUrl: config.apiUrl,
        apiKey: config.apiKey,
      );

      if (onlineRate != null) {
        if (persistOnlineRate) {
          try {
            await _doc.set({
              'rate': onlineRate.rate,
              'source': onlineRate.source,
              'rateDate': onlineRate.rateDate,
              'lastOnlineSyncAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
              'apiUrl': config.apiUrl,
              if (config.apiKey.isNotEmpty) 'apiKey': config.apiKey,
            }, SetOptions(merge: true));
          } catch (_) {
            // Clientes y tecnicos pueden calcular con la tasa, pero solo owner
            // debe poder guardar configuracion en Firestore.
          }
        }
        return onlineRate;
      }
    }

    if (config.rate > 0) {
      return BcvRate(
        rate: config.rate,
        source: config.source,
        rateDate: config.rateDate,
        fromInternet: false,
      );
    }

    return const BcvRate(
      rate: 0,
      source: 'BCV no configurado',
      rateDate: '',
      fromInternet: false,
    );
  }

  static Future<void> saveManualRate({
    required double rate,
    required String source,
    required String rateDate,
    required String apiUrl,
    required String apiKey,
  }) async {
    await _doc.set({
      'rate': rate,
      'source': source.trim().isEmpty ? 'BCV manual' : source.trim(),
      'rateDate': rateDate.trim(),
      'apiUrl': apiUrl.trim().isEmpty ? defaultApiUrl : apiUrl.trim(),
      'apiKey': apiKey.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<_BcvConfig> _readConfig() async {
    Map<String, dynamic> data = {};

    try {
      final snapshot = await _doc.get().timeout(const Duration(seconds: 5));
      data = snapshot.data() ?? {};
    } catch (_) {
      data = {};
    }

    return _BcvConfig(
      rate: (data['rate'] as num?)?.toDouble() ?? 0,
      source: data['source']?.toString() ?? 'BCV',
      rateDate: data['rateDate']?.toString() ?? '',
      apiUrl: data['apiUrl']?.toString().trim().isNotEmpty == true
          ? data['apiUrl'].toString().trim()
          : defaultApiUrl,
      apiKey: data['apiKey']?.toString().trim() ?? '',
    );
  }

  static Future<BcvRate?> _fetchOnlineRate({
    required String apiUrl,
    required String apiKey,
  }) async {
    try {
      final headers = <String, String>{
        'Accept': 'application/json',
        if (apiKey.isNotEmpty) 'Authorization': apiKey,
        if (apiKey.isNotEmpty) 'x-api-key': apiKey,
      };

      final response = await http
          .get(Uri.parse(apiUrl), headers: headers)
          .timeout(const Duration(seconds: 8));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic> && decoded is! List) return null;

      final rate = _extractRate(decoded);
      if (rate == null || rate <= 0) return null;

      return BcvRate(
        rate: double.parse(rate.toStringAsFixed(4)),
        source: _extractText(decoded, [
              'fuente',
              'source',
              'nombre',
              'name',
            ]) ??
            'BCV automatico',
        rateDate: _extractText(decoded, [
              'fecha',
              'date',
              'fechaActualizacion',
              'last_update',
              'updated_at',
            ]) ??
            DateTime.now().toIso8601String(),
        fromInternet: true,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<BcvRate?> _fetchOnlineRateWithFallbacks({
    required String apiUrl,
    required String apiKey,
  }) async {
    final urls = <String>[
      if (apiUrl.trim().isNotEmpty) apiUrl.trim(),
      ...fallbackApiUrls,
    ];
    final uniqueUrls = <String>{};

    for (final url in urls.where(uniqueUrls.add)) {
      final rate = await _fetchOnlineRate(
        apiUrl: url,
        apiKey: apiKey,
      );
      if (rate != null) return rate;
    }

    return null;
  }

  static double? _extractRate(dynamic payload) {
    if (payload is List) {
      for (final item in payload) {
        final value = _extractRate(item);
        if (value != null) return value;
      }
      return null;
    }

    if (payload is! Map) return null;

    final data = payload.cast<String, dynamic>();

    for (final key in [
      'promedio',
      'price',
      'precio',
      'tasa',
      'rate',
      'valor',
      'value',
      'venta',
      'compra',
    ]) {
      final value = _toDouble(data[key]);
      if (value != null) return value;
    }

    for (final key in [
      'usd',
      'USD',
      'dolar',
      'dollar',
      'oficial',
      'bcv',
      'BCV',
      'monitors',
    ]) {
      final nested = data[key];
      final value = _extractRate(nested);
      if (value != null) return value;
    }

    return null;
  }

  static String? _extractText(dynamic payload, List<String> keys) {
    if (payload is List) {
      for (final item in payload) {
        final value = _extractText(item, keys);
        if (value != null && value.isNotEmpty) return value;
      }
      return null;
    }

    if (payload is! Map) return null;
    final data = payload.cast<String, dynamic>();

    for (final key in keys) {
      final value = data[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }

    for (final nested in data.values) {
      if (nested is Map || nested is List) {
        final value = _extractText(nested, keys);
        if (value != null && value.isNotEmpty) return value;
      }
    }

    return null;
  }

  static double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value.replaceAll(',', '.'));
    }
    return null;
  }
}

class _BcvConfig {
  final double rate;
  final String source;
  final String rateDate;
  final String apiUrl;
  final String apiKey;

  const _BcvConfig({
    required this.rate,
    required this.source,
    required this.rateDate,
    required this.apiUrl,
    required this.apiKey,
  });
}
