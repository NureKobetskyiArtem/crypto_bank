// lib/models/models.dart

// ── User ──────────────────────────────────────────────────────────────────────
//
// Профиль пользователя приложения. Поля firstName/lastName/countryId
// соответствуют тому, что принимает и возвращает Auth API backend-а.
// accessToken хранится тут же, чтобы его было удобно прокидывать
// в авторизованные запросы (Cards API и т.д.).

class UserProfile {
  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final int countryId;
  final DateTime createdAt;
  final String accessToken;

  UserProfile({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.createdAt,
    required this.accessToken,
    this.countryId = 1,
  });

  /// Полное имя — используется в UI там, где раньше было displayName.
  String get displayName => '$firstName $lastName'.trim();

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'firstName': firstName,
        'lastName': lastName,
        'countryId': countryId,
        'createdAt': createdAt.toIso8601String(),
        'accessToken': accessToken,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: json['id'],
        email: json['email'],
        firstName: json['firstName'] ?? '',
        lastName: json['lastName'] ?? '',
        countryId: json['countryId'] ?? 1,
        createdAt: DateTime.parse(json['createdAt']),
        accessToken: json['accessToken'] ?? '',
      );

  UserProfile copyWith({String? accessToken}) => UserProfile(
        id: id,
        email: email,
        firstName: firstName,
        lastName: lastName,
        countryId: countryId,
        createdAt: createdAt,
        accessToken: accessToken ?? this.accessToken,
      );
}

// ── Enums ─────────────────────────────────────────────────────────────────────

enum TransactionType {
  cryptoReceived,
  cryptoSent,
  cryptoToFiat,     // крипто → EUR или USD
  fiatToCrypto,     // EUR/USD → крипто
  cardPayment,      // перевод с EUR-карты
  cardPaymentUsd,   // перевод с USD-карты
  cryptoSwap,       // USDT ↔ USDC
  cardTopup,
}

enum CryptoAsset { usdt, usdc }

extension CryptoAssetExt on CryptoAsset {
  String get symbol => name.toUpperCase();
  String get network => this == CryptoAsset.usdt ? 'TRC-20' : 'Polygon';
  String get fullName =>
      this == CryptoAsset.usdt ? 'Tether USD' : 'USD Coin';
  String get coingeckoId =>
      this == CryptoAsset.usdt ? 'tether' : 'usd-coin';
}

// Валюта фиатной карты
enum FiatCurrency { eur, usd }

extension FiatCurrencyExt on FiatCurrency {
  String get code => name.toUpperCase();
  String get symbol => this == FiatCurrency.eur ? '€' : '\$';
  String get label => this == FiatCurrency.eur ? 'Euro' : 'US Dollar';
}

// ── Transaction ───────────────────────────────────────────────────────────────

class Transaction {
  final String id;
  final TransactionType type;
  final double amount;
  final String currency;       // исходная валюта
  final DateTime date;
  final String description;
  final double? secondAmount;
  final String? secondCurrency;
  // Card payments
  final String? recipientCard;
  final String? recipientName;
  final String? note;
  // Crypto swap
  final String? swapFromAsset;
  final String? swapToAsset;
  // Какой карте принадлежит транзакция
  final String? cardCurrency; // 'EUR' или 'USD'

  Transaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.currency,
    required this.date,
    required this.description,
    this.secondAmount,
    this.secondCurrency,
    this.recipientCard,
    this.recipientName,
    this.note,
    this.swapFromAsset,
    this.swapToAsset,
    this.cardCurrency,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.index,
        'amount': amount,
        'currency': currency,
        'date': date.toIso8601String(),
        'description': description,
        'secondAmount': secondAmount,
        'secondCurrency': secondCurrency,
        'recipientCard': recipientCard,
        'recipientName': recipientName,
        'note': note,
        'swapFromAsset': swapFromAsset,
        'swapToAsset': swapToAsset,
        'cardCurrency': cardCurrency,
      };

  factory Transaction.fromJson(Map<String, dynamic> json) => Transaction(
        id: json['id'],
        type: TransactionType.values[json['type']],
        amount: (json['amount'] as num).toDouble(),
        currency: json['currency'],
        date: DateTime.parse(json['date']),
        description: json['description'],
        secondAmount: json['secondAmount'] != null
            ? (json['secondAmount'] as num).toDouble()
            : null,
        secondCurrency: json['secondCurrency'],
        recipientCard: json['recipientCard'],
        recipientName: json['recipientName'],
        note: json['note'],
        swapFromAsset: json['swapFromAsset'],
        swapToAsset: json['swapToAsset'],
        cardCurrency: json['cardCurrency'],
      );
}

// ── Virtual Card ──────────────────────────────────────────────────────────────
//
// Визуальная модель карты в приложении. holderName/isActive — чисто фронтовые
// поля (backend их не возвращает), а number/cvv/expiry/currency синхронизируются
// с данными карты на backend, когда они доступны (см. ApiCard в api_client.dart).
// apiId — id карты на backend, используется для GET /api/cards/{id}.

class VirtualCard {
  final String number;
  final String holderName;
  final String expiry;
  final String cvv;
  final bool isActive;
  final String currency; // 'EUR' or 'USD'
  final String? apiId; // id карты на backend (если карта синхронизирована с API)
  final int? apiCurrencyId; // currencyId, который backend ожидает/возвращает

  VirtualCard({
    required this.number,
    required this.holderName,
    required this.expiry,
    required this.cvv,
    this.isActive = true,
    this.currency = 'EUR',
    this.apiId,
    this.apiCurrencyId,
  });

  String get maskedNumber {
    final digits = number.replaceAll(' ', '');
    if (digits.length < 4) return number;
    return '**** **** **** ${digits.substring(digits.length - 4)}';
  }

  VirtualCard copyWith({
    String? number,
    String? holderName,
    String? expiry,
    String? cvv,
    bool? isActive,
    String? currency,
    String? apiId,
    int? apiCurrencyId,
  }) => VirtualCard(
        number: number ?? this.number,
        holderName: holderName ?? this.holderName,
        expiry: expiry ?? this.expiry,
        cvv: cvv ?? this.cvv,
        isActive: isActive ?? this.isActive,
        currency: currency ?? this.currency,
        apiId: apiId ?? this.apiId,
        apiCurrencyId: apiCurrencyId ?? this.apiCurrencyId,
      );

  Map<String, dynamic> toJson() => {
        'number': number,
        'holderName': holderName,
        'expiry': expiry,
        'cvv': cvv,
        'isActive': isActive,
        'currency': currency,
        'apiId': apiId,
        'apiCurrencyId': apiCurrencyId,
      };

  factory VirtualCard.fromJson(Map<String, dynamic> json) => VirtualCard(
        number: json['number'],
        holderName: json['holderName'],
        expiry: json['expiry'],
        cvv: json['cvv'],
        isActive: json['isActive'] ?? true,
        currency: json['currency'] ?? 'EUR',
        apiId: json['apiId'],
        apiCurrencyId: json['apiCurrencyId'],
      );
}

// ── Exchange Rates ────────────────────────────────────────────────────────────

class ExchangeRates {
  final double usdtToUsd;
  final double usdcToUsd;
  final double usdToEur;
  final double usdToGbp;
  final double usdToUah;
  final double btcToUsd;
  final double ethToUsd;
  final DateTime updatedAt;

  ExchangeRates({
    required this.usdtToUsd,
    required this.usdcToUsd,
    required this.usdToEur,
    required this.usdToGbp,
    required this.usdToUah,
    required this.btcToUsd,
    required this.ethToUsd,
    required this.updatedAt,
  });

  double get usdtToEur => usdtToUsd * usdToEur;
  double get usdcToEur => usdcToUsd * usdToEur;
  double get usdToEurRate => usdToEur;

  static ExchangeRates fallback() => ExchangeRates(
        usdtToUsd: 1.0,
        usdcToUsd: 1.0,
        usdToEur: 0.92,
        usdToGbp: 0.79,
        usdToUah: 41.5,
        btcToUsd: 105000,
        ethToUsd: 2500,
        updatedAt: DateTime.now(),
      );
}
