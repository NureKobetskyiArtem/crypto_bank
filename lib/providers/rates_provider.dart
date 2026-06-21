// lib/providers/rates_provider.dart
//
// Загружает реальные курсы с CoinGecko (бесплатный API, без ключа)
// и exchangerate.host для фиатных пар.
// Обновляется каждые 60 секунд.

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/models.dart';

class RatesProvider extends ChangeNotifier {
  ExchangeRates _rates = ExchangeRates.fallback();
  bool _isLoading = false;
  bool _hasError = false;
  String _errorMsg = '';
  DateTime? _lastFetch;
  Timer? _timer;

  ExchangeRates get rates => _rates;
  bool get isLoading => _isLoading;
  bool get hasError => _hasError;
  String get errorMsg => _errorMsg;
  DateTime? get lastFetch => _lastFetch;

  // Convenience getters for UI
  double get usdtToEur => _rates.usdtToEur;
  double get usdcToEur => _rates.usdcToEur;
  double get usdToEur => _rates.usdToEur;
  double get usdToGbp => _rates.usdToGbp;
  double get usdToUah => _rates.usdToUah;
  double get btcToUsd => _rates.btcToUsd;
  double get ethToUsd => _rates.ethToUsd;
  double get usdtToUsd => _rates.usdtToUsd;
  double get usdcToUsd => _rates.usdcToUsd;

  RatesProvider() {
    fetchRates();
    // Auto-refresh every 60 seconds
    _timer = Timer.periodic(const Duration(seconds: 60), (_) => fetchRates());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> fetchRates() async {
    _isLoading = true;
    _hasError = false;
    notifyListeners();

    try {
      // ── Step 1: Crypto prices in USD (CoinGecko free API) ──────────────────
      final cryptoUri = Uri.parse(
        'https://api.coingecko.com/api/v3/simple/price'
        '?ids=tether,usd-coin,bitcoin,ethereum'
        '&vs_currencies=usd',
      );

      final cryptoRes = await http
          .get(cryptoUri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));

      Map<String, dynamic> cryptoData = {};
      if (cryptoRes.statusCode == 200) {
        cryptoData = jsonDecode(cryptoRes.body);
      }

      final usdtToUsd =
          (cryptoData['tether']?['usd'] as num?)?.toDouble() ?? 1.0;
      final usdcToUsd =
          (cryptoData['usd-coin']?['usd'] as num?)?.toDouble() ?? 1.0;
      final btcToUsd =
          (cryptoData['bitcoin']?['usd'] as num?)?.toDouble() ?? 105000.0;
      final ethToUsd =
          (cryptoData['ethereum']?['usd'] as num?)?.toDouble() ?? 2500.0;

      // ── Step 2: Fiat rates (exchangerate-api free endpoint) ────────────────
      double usdToEur = 0.92;
      double usdToGbp = 0.79;
      double usdToUah = 41.5;

      try {
        final fiatUri = Uri.parse(
          'https://open.er-api.com/v6/latest/USD',
        );
        final fiatRes = await http
            .get(fiatUri, headers: {'Accept': 'application/json'})
            .timeout(const Duration(seconds: 8));

        if (fiatRes.statusCode == 200) {
          final fiatData = jsonDecode(fiatRes.body);
          final rates = fiatData['rates'] as Map<String, dynamic>?;
          if (rates != null) {
            usdToEur = (rates['EUR'] as num?)?.toDouble() ?? usdToEur;
            usdToGbp = (rates['GBP'] as num?)?.toDouble() ?? usdToGbp;
            usdToUah = (rates['UAH'] as num?)?.toDouble() ?? usdToUah;
          }
        }
      } catch (_) {
        // Fiat API failed — use cached or fallback values
      }

      _rates = ExchangeRates(
        usdtToUsd: usdtToUsd,
        usdcToUsd: usdcToUsd,
        usdToEur: usdToEur,
        usdToGbp: usdToGbp,
        usdToUah: usdToUah,
        btcToUsd: btcToUsd,
        ethToUsd: ethToUsd,
        updatedAt: DateTime.now(),
      );

      _lastFetch = DateTime.now();
      _hasError = false;
    } catch (e) {
      _hasError = true;
      _errorMsg = 'Failed to fetch rates. Using cached values.';
      // Keep existing _rates (fallback or last successful)
    }

    _isLoading = false;
    notifyListeners();
  }
}
