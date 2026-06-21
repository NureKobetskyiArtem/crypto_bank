// lib/providers/wallet_provider.dart

import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/api_client.dart';
import '../services/api_enums.dart';
import 'rates_provider.dart';

class WalletProvider extends ChangeNotifier {
  final RatesProvider ratesProvider;
  final ApiClient _api = ApiClient.instance;

  // Crypto balances
  double _usdtBalance = 0.0;
  double _usdcBalance = 0.0;

  // Fiat balances (EUR and USD separate)
  double _eurBalance = 0.0;
  double _usdBalance = 0.0;

  // Addresses
  String _usdtAddress = '';
  String _usdcAddress = '';

  // Cards (EUR + USD)
  VirtualCard? _eurCard;
  VirtualCard? _usdCard;

  // Transactions
  List<Transaction> _transactions = [];

  bool _isLoading = false;
  String? _error;

  // ── Fees ──────────────────────────────────────────────────────────────────
  double get exchangeFeePercent => 1.5;
  double get buyFeePercent => 2.0;
  double get swapFeePercent => 0.5;

  // ── Live rates ────────────────────────────────────────────────────────────
  double get usdtToEurRate => ratesProvider.usdtToEur;
  double get usdcToEurRate => ratesProvider.usdcToEur;
  double get usdtToUsdRate => ratesProvider.usdtToUsd;
  double get usdcToUsdRate => ratesProvider.usdcToUsd;

  double fiatRate(CryptoAsset asset, String currency) {
    if (currency == 'USD') {
      return asset == CryptoAsset.usdt ? usdtToUsdRate : usdcToUsdRate;
    }
    return asset == CryptoAsset.usdt ? usdtToEurRate : usdcToEurRate;
  }

  // ── Getters ───────────────────────────────────────────────────────────────
  double get usdtBalance => _usdtBalance;
  double get usdcBalance => _usdcBalance;
  double get eurBalance => _eurBalance;
  double get usdBalance => _usdBalance;

  // Legacy accessor used by older screens (EUR)
  double get fiatBalance => _eurBalance;
  String get fiatCurrency => 'EUR';

  String get usdtAddress => _usdtAddress;
  String get usdcAddress => _usdcAddress;

  VirtualCard? get eurCard => _eurCard;
  VirtualCard? get usdCard => _usdCard;

  // Legacy accessor
  VirtualCard? get card => _eurCard;
  bool get hasCard => _eurCard != null || _usdCard != null;
  bool get hasEurCard => _eurCard != null;
  bool get hasUsdCard => _usdCard != null;

  List<Transaction> get transactions {
    final list = List.of(_transactions);
    list.sort((a, b) => b.date.compareTo(a.date));
    return List.unmodifiable(list);
  }

  /// Транзакции только для EUR-карты
  List<Transaction> get eurCardTransactions => transactions
      .where((t) =>
          t.cardCurrency == 'EUR' ||
          (t.cardCurrency == null &&
              t.type == TransactionType.cardPayment))
      .toList();

  /// Транзакции только для USD-карты
  List<Transaction> get usdCardTransactions => transactions
      .where((t) => t.cardCurrency == 'USD' ||
          t.type == TransactionType.cardPaymentUsd)
      .toList();

  bool get isLoading => _isLoading;
  String? get error => _error;

  WalletProvider({required this.ratesProvider}) {
    _init();
  }

  Future<void> _init() async {
    _setLoading(true);
    await _load();
    if (_usdtAddress.isEmpty) {
      _usdtAddress = _generateAddress('T');
      _usdcAddress = _generateAddress('0x');
      await _save();
    }
    _setLoading(false);
  }

  // ── Sync cards with backend (Cards API) ──────────────────────────────────
  //
  // GET /api/cards — подтягивает реальные карты пользователя с backend
  // и обновляет cardNumber/cvv/expiryDate/balance. holderName/isActive
  // у backend нет, поэтому для новых карт используется имя пользователя,
  // а для уже существующих локальных карт оно сохраняется как есть.

  Future<void> syncCardsFromApi(String accessToken, {String? holderNameFallback}) async {
    _setLoading(true);
    try {
      final apiCards = await _api.getCards(accessToken);

      ApiCard? eurApiCard;
      ApiCard? usdApiCard;
      for (final c in apiCards) {
        if (c.currency == CurrencyId.eur && eurApiCard == null) {
          eurApiCard = c;
        } else if (c.currency == CurrencyId.usd && usdApiCard == null) {
          usdApiCard = c;
        }
      }

      if (eurApiCard != null) {
        _eurCard = _mergeApiCard(_eurCard, eurApiCard, 'EUR', holderNameFallback);
        _eurBalance = eurApiCard.balance;
      }
      if (usdApiCard != null) {
        _usdCard = _mergeApiCard(_usdCard, usdApiCard, 'USD', holderNameFallback);
        _usdBalance = usdApiCard.balance;
      }

      await _save();
    } catch (e) {
      _setError('Failed to sync cards: $e');
    }
    _setLoading(false);
  }

  VirtualCard _mergeApiCard(
    VirtualCard? existing,
    ApiCard apiCard,
    String currency,
    String? holderNameFallback,
  ) {
    final holderName = existing?.holderName ??
        (holderNameFallback?.trim().isNotEmpty == true
            ? holderNameFallback!.trim().toUpperCase()
            : 'CARD HOLDER');
    return VirtualCard(
      number: apiCard.cardNumber,
      holderName: holderName,
      expiry: apiCard.expiryDate,
      cvv: apiCard.cvv,
      isActive: existing?.isActive ?? true,
      currency: currency,
      apiId: apiCard.id,
      apiCurrencyId: apiCard.currencyId,
    );
  }

  // ── Simulate receive ──────────────────────────────────────────────────────

  Future<void> simulateReceive(CryptoAsset asset, double amount) async {
    if (amount <= 0) { _setError('Amount must be greater than 0'); return; }
    _setLoading(true);
    await Future.delayed(const Duration(milliseconds: 800));
    if (asset == CryptoAsset.usdt) {
      _usdtBalance += amount;
    } else {
      _usdcBalance += amount;
    }
    _addTx(Transaction(
      id: _uuid(), type: TransactionType.cryptoReceived,
      amount: amount, currency: asset.symbol, date: DateTime.now(),
      description: 'Received ${asset.symbol} (${asset.network})',
    ));
    await _save();
    _setLoading(false);
  }

  // ── Send crypto ───────────────────────────────────────────────────────────

  Future<String?> sendCrypto(CryptoAsset asset, double amount, String toAddress) async {
    if (amount <= 0) return 'Amount must be greater than 0';
    if (toAddress.trim().isEmpty) return 'Enter a destination address';
    final bal = asset == CryptoAsset.usdt ? _usdtBalance : _usdcBalance;
    if (amount > bal) return 'Insufficient ${asset.symbol} balance';

    _setLoading(true);
    await Future.delayed(const Duration(milliseconds: 1000));
    if (asset == CryptoAsset.usdt) {
      _usdtBalance -= amount;
    } else {
      _usdcBalance -= amount;
    }
    _addTx(Transaction(
      id: _uuid(), type: TransactionType.cryptoSent,
      amount: amount, currency: asset.symbol, date: DateTime.now(),
      description: 'Sent ${asset.symbol} to ${toAddress.substring(0, min(10, toAddress.length))}…',
    ));
    await _save();
    _setLoading(false);
    return null;
  }

  // ── Convert crypto → fiat (EUR or USD) ───────────────────────────────────

  Future<String?> convertCryptoToFiat(
      CryptoAsset asset, double amount, String targetCurrency) async {
    if (amount <= 0) return 'Amount must be greater than 0';
    final bal = asset == CryptoAsset.usdt ? _usdtBalance : _usdcBalance;
    if (amount > bal) return 'Insufficient ${asset.symbol} balance';

    _setLoading(true);
    await Future.delayed(const Duration(milliseconds: 900));

    final rate = fiatRate(asset, targetCurrency);
    final gross = amount * rate;
    final fee = gross * exchangeFeePercent / 100;
    final net = gross - fee;

    if (asset == CryptoAsset.usdt) {
      _usdtBalance -= amount;
    } else {
      _usdcBalance -= amount;
    }
    if (targetCurrency == 'USD') {
      _usdBalance += net;
    } else {
      _eurBalance += net;
    }

    _addTx(Transaction(
      id: _uuid(), type: TransactionType.cryptoToFiat,
      amount: amount, currency: asset.symbol, date: DateTime.now(),
      description: 'Converted ${asset.symbol} → $targetCurrency',
      secondAmount: net, secondCurrency: targetCurrency,
    ));
    await _save();
    _setLoading(false);
    return null;
  }

  // ── Buy crypto with card (EUR or USD balance) ─────────────────────────────

  Future<String?> buyCryptoWithCard(
      CryptoAsset asset, double fiatAmount, String sourceCurrency) async {
    if (fiatAmount <= 0) return 'Amount must be greater than 0';
    final bal = sourceCurrency == 'USD' ? _usdBalance : _eurBalance;
    if (fiatAmount > bal) return 'Insufficient $sourceCurrency balance';

    _setLoading(true);
    await Future.delayed(const Duration(milliseconds: 1000));

    final rate = fiatRate(asset, sourceCurrency);
    final fee = fiatAmount * buyFeePercent / 100;
    final net = fiatAmount - fee;
    final cryptoAmount = net / rate;

    if (sourceCurrency == 'USD') {
      _usdBalance -= fiatAmount;
    } else {
      _eurBalance -= fiatAmount;
    }
    if (asset == CryptoAsset.usdt) {
      _usdtBalance += cryptoAmount;
    } else {
      _usdcBalance += cryptoAmount;
    }

    _addTx(Transaction(
      id: _uuid(), type: TransactionType.fiatToCrypto,
      amount: fiatAmount, currency: sourceCurrency, date: DateTime.now(),
      description: 'Bought ${asset.symbol} with $sourceCurrency',
      secondAmount: cryptoAmount, secondCurrency: asset.symbol,
    ));
    await _save();
    _setLoading(false);
    return null;
  }

  // ── Crypto swap: USDT ↔ USDC ──────────────────────────────────────────────

  Future<String?> swapCrypto(
      CryptoAsset from, CryptoAsset to, double amount) async {
    if (from == to) return 'Select different assets';
    if (amount <= 0) return 'Amount must be greater than 0';
    final bal = from == CryptoAsset.usdt ? _usdtBalance : _usdcBalance;
    if (amount > bal) return 'Insufficient ${from.symbol} balance';

    _setLoading(true);
    await Future.delayed(const Duration(milliseconds: 1000));

    // Both are stablecoins ≈ 1 USD, apply small fee
    final fee = amount * swapFeePercent / 100;
    final received = amount - fee;

    if (from == CryptoAsset.usdt) {
      _usdtBalance -= amount;
      _usdcBalance += received;
    } else {
      _usdcBalance -= amount;
      _usdtBalance += received;
    }

    _addTx(Transaction(
      id: _uuid(), type: TransactionType.cryptoSwap,
      amount: amount, currency: from.symbol, date: DateTime.now(),
      description: 'Swapped ${from.symbol} → ${to.symbol}',
      secondAmount: received, secondCurrency: to.symbol,
      swapFromAsset: from.symbol, swapToAsset: to.symbol,
    ));
    await _save();
    _setLoading(false);
    return null;
  }

  // ── Card payment ──────────────────────────────────────────────────────────

  Future<String?> cardPayment({
    required double amount,
    required String cardCurrency, // 'EUR' or 'USD'
    required String recipientCard,
    required String recipientName,
    String? note,
  }) async {
    final isUsd = cardCurrency == 'USD';
    if (isUsd && !hasUsdCard) return 'No USD card issued';
    if (!isUsd && !hasEurCard) return 'No EUR card issued';
    if (amount <= 0) return 'Amount must be greater than 0';
    final bal = isUsd ? _usdBalance : _eurBalance;
    if (amount > bal) return 'Insufficient $cardCurrency balance';
    if (recipientCard.trim().isEmpty) return 'Enter recipient card or IBAN';
    if (recipientName.trim().isEmpty) return 'Enter recipient name';

    _setLoading(true);
    await Future.delayed(const Duration(milliseconds: 1200));

    if (isUsd) {
      _usdBalance -= amount;
    } else {
      _eurBalance -= amount;
    }

    final masked = _maskRecipient(recipientCard.trim());
    _addTx(Transaction(
      id: _uuid(),
      type: isUsd ? TransactionType.cardPaymentUsd : TransactionType.cardPayment,
      amount: amount, currency: cardCurrency, date: DateTime.now(),
      description: note?.isNotEmpty == true
          ? '${note!.trim()} → $masked'
          : 'Transfer to $masked',
      recipientCard: recipientCard.trim(),
      recipientName: recipientName.trim(),
      note: note?.trim(),
      cardCurrency: cardCurrency,
    ));
    await _save();
    _setLoading(false);
    return null;
  }

  // ── Issue card ────────────────────────────────────────────────────────────
  //
  // POST /api/cards — создаёт карту на backend по currencyId (EUR=1, USD=2 —
  // см. services/api_enums.dart). holderName на backend не передаётся
  // (API его не принимает), но сохраняется локально для отображения на карте.

  Future<String?> issueCard(
    String holderName,
    String currency, {
    String? accessToken,
  }) async {
    if (holderName.trim().isEmpty) return 'Enter cardholder name';
    _setLoading(true);

    final currencyId =
        currency == 'USD' ? CurrencyId.usd.id : CurrencyId.eur.id;

    if (accessToken != null && accessToken.isNotEmpty) {
      try {
        final apiCard = await _api.createCard(accessToken, currencyId);
        final card = VirtualCard(
          number: apiCard.cardNumber,
          holderName: holderName.trim().toUpperCase(),
          expiry: apiCard.expiryDate,
          cvv: apiCard.cvv,
          currency: currency,
          apiId: apiCard.id,
          apiCurrencyId: apiCard.currencyId,
        );
        if (currency == 'USD') {
          _usdCard = card;
          _usdBalance = apiCard.balance;
        } else {
          _eurCard = card;
          _eurBalance = apiCard.balance;
        }
        await _save();
        _setLoading(false);
        return null;
      } on ApiException catch (e) {
        _setLoading(false);
        return e.message;
      } catch (e) {
        _setLoading(false);
        return 'Failed to issue card: $e';
      }
    }

    // Без accessToken (например, гостевой режим) — карту выпустить нельзя,
    // так как Cards API требует авторизации.
    _setLoading(false);
    return 'Sign in required to issue a card';
  }

  // ── Persistence ───────────────────────────────────────────────────────────

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('usdtBalance', _usdtBalance);
    await prefs.setDouble('usdcBalance', _usdcBalance);
    await prefs.setDouble('eurBalance', _eurBalance);
    await prefs.setDouble('usdBalance', _usdBalance);
    await prefs.setString('usdtAddress', _usdtAddress);
    await prefs.setString('usdcAddress', _usdcAddress);
    await prefs.setStringList(
        'transactions',
        _transactions.map((t) => jsonEncode(t.toJson())).toList());
    if (_eurCard != null) {
      await prefs.setString('eurCard', jsonEncode(_eurCard!.toJson()));
    }
    if (_usdCard != null) {
      await prefs.setString('usdCard', jsonEncode(_usdCard!.toJson()));
    }
    notifyListeners();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _usdtBalance = prefs.getDouble('usdtBalance') ?? 0.0;
    _usdcBalance = prefs.getDouble('usdcBalance') ?? 0.0;
    // Migrate old single fiatBalance → eurBalance
    _eurBalance = prefs.getDouble('eurBalance') ??
        prefs.getDouble('fiatBalance') ?? 0.0;
    _usdBalance = prefs.getDouble('usdBalance') ?? 0.0;
    _usdtAddress = prefs.getString('usdtAddress') ?? '';
    _usdcAddress = prefs.getString('usdcAddress') ?? '';
    _transactions = (prefs.getStringList('transactions') ?? [])
        .map((s) => Transaction.fromJson(jsonDecode(s)))
        .toList();
    final eurCardStr = prefs.getString('eurCard') ??
        prefs.getString('card'); // migrate old key
    if (eurCardStr != null) {
      _eurCard = VirtualCard.fromJson(jsonDecode(eurCardStr));
    }
    final usdCardStr = prefs.getString('usdCard');
    if (usdCardStr != null) {
      _usdCard = VirtualCard.fromJson(jsonDecode(usdCardStr));
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _addTx(Transaction tx) => _transactions.add(tx);

  void _setLoading(bool val) {
    _isLoading = val;
    _error = null;
    notifyListeners();
  }

  void _setError(String msg) {
    _error = msg;
    notifyListeners();
  }

  void clearError() { _error = null; notifyListeners(); }

  String _generateAddress(String prefix) {
    const chars = '0123456789abcdef';
    final rand = Random.secure();
    return prefix +
        List.generate(34, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  String _uuid() {
    final rand = Random.secure();
    final bytes = List.generate(16, (_) => rand.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String hex(int b) => b.toRadixString(16).padLeft(2, '0');
    return [
      bytes.sublist(0, 4).map(hex).join(),
      bytes.sublist(4, 6).map(hex).join(),
      bytes.sublist(6, 8).map(hex).join(),
      bytes.sublist(8, 10).map(hex).join(),
      bytes.sublist(10, 16).map(hex).join(),
    ].join('-');
  }

  String _maskRecipient(String input) {
    final clean = input.replaceAll(RegExp(r'\s'), '');
    if (clean.length <= 8) return input;
    return '${clean.substring(0, 4)}****${clean.substring(clean.length - 4)}';
  }

  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    _usdtBalance = 0; _usdcBalance = 0;
    _eurBalance = 0; _usdBalance = 0;
    _eurCard = null; _usdCard = null;
    _transactions = [];
    _usdtAddress = _generateAddress('T');
    _usdcAddress = _generateAddress('0x');
    await _save();
  }
}
