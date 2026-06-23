// lib/services/api_client.dart
//
// Единая точка входа для всех HTTP-запросов к backend.
// Реализует Auth API (register/login) и Cards API (list/get/create)
// согласно документации, предоставленной преподавателем/заказчиком.

import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_enums.dart';

/// Базовый URL backend API.
/// Поменяй здесь, если адрес сервера изменится (например, при деплое).
const String kApiBaseUrl = 'http://localhost:5036';

/// Общее исключение для ошибок API. Хранит человекочитаемое сообщение,
/// которое можно показать напрямую в UI.
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

// ── DTO: ответы backend ────────────────────────────────────────────────────

/// Пользователь, как его возвращает backend (Auth API).
class ApiUser {
  final String id;
  final String firstName;
  final String lastName;
  final String email;

  ApiUser({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
  });

  String get fullName => '$firstName $lastName'.trim();

  factory ApiUser.fromJson(Map<String, dynamic> json) => ApiUser(
        id: json['id'].toString(),
        firstName: json['firstName'] ?? '',
        lastName: json['lastName'] ?? '',
        email: json['email'] ?? '',
      );
}

/// Результат запросов register/login: токен + пользователь.
class AuthResult {
  final String accessToken;
  final ApiUser user;
  AuthResult({required this.accessToken, required this.user});

  factory AuthResult.fromJson(Map<String, dynamic> json) => AuthResult(
        accessToken: json['accessToken'] as String,
        user: ApiUser.fromJson(json['user'] as Map<String, dynamic>),
      );
}

/// Карта, как её возвращает backend (Cards API).
/// Бэкенд отдаёт только эти поля — без имени держателя и без статуса активности,
/// поэтому такие детали на фронтенде достраиваются локально (см. WalletProvider).
class ApiCard {
  final String id;
  final int currencyId;
  final String cardNumber;
  final String cvv;
  final double balance;
  final String expiryDate;

  ApiCard({
    required this.id,
    required this.currencyId,
    required this.cardNumber,
    required this.cvv,
    required this.balance,
    required this.expiryDate,
  });

  CurrencyId get currency => CurrencyId.fromId(currencyId);

  factory ApiCard.fromJson(Map<String, dynamic> json) => ApiCard(
        id: json['id'].toString(),
        currencyId: json['currencyId'] is int
            ? json['currencyId'] as int
            : int.tryParse(json['currencyId'].toString()) ?? 0,
        cardNumber: json['cardNumber']?.toString() ?? '',
        cvv: json['cvv']?.toString() ?? '',
        balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
        expiryDate: json['expiryDate']?.toString() ?? '',
      );
}

/// Кошелёк, как его возвращает backend (Wallets API).
class ApiWallet {
  final String id;
  final String address;
  final String currencyCode;
  final double balance;
  final DateTime? createdAt;

  ApiWallet({
    required this.id,
    required this.address,
    required this.currencyCode,
    required this.balance,
    this.createdAt,
  });

  factory ApiWallet.fromJson(Map<String, dynamic> json) => ApiWallet(
        id: json['id'].toString(),
        address: json['address']?.toString() ?? '',
        currencyCode: json['currencyCode']?.toString() ?? '',
        balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'].toString())
            : null,
      );
}

/// Транзакция, как её возвращает backend (Transactions API).
class ApiTransaction {
  final String id;
  final String type;
  final String status;
  final int? fromCurrencyId;
  final double? fromAmount;
  final int? toCurrencyId;
  final double? toAmount;
  final bool isExternal;
  final String? recipientReference;
  final DateTime? createdAt;

  ApiTransaction({
    required this.id,
    required this.type,
    required this.status,
    this.fromCurrencyId,
    this.fromAmount,
    this.toCurrencyId,
    this.toAmount,
    this.isExternal = false,
    this.recipientReference,
    this.createdAt,
  });

  factory ApiTransaction.fromJson(Map<String, dynamic> json) => ApiTransaction(
        id: json['id'].toString(),
        type: json['type']?.toString() ?? '',
        status: json['status']?.toString() ?? '',
        fromCurrencyId: json['fromCurrencyId'] is int
            ? json['fromCurrencyId'] as int
            : int.tryParse(json['fromCurrencyId']?.toString() ?? ''),
        fromAmount: (json['fromAmount'] as num?)?.toDouble(),
        toCurrencyId: json['toCurrencyId'] is int
            ? json['toCurrencyId'] as int
            : int.tryParse(json['toCurrencyId']?.toString() ?? ''),
        toAmount: (json['toAmount'] as num?)?.toDouble(),
        isExternal: json['isExternal'] == true,
        recipientReference: json['recipientReference']?.toString(),
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'].toString())
            : null,
      );
}

/// Текущий пользователь (Users API: GET /api/users/me).
class ApiMe {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final DateTime? dateOfBirth;
  final String countryName;
  final DateTime? createdAt;

  ApiMe({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.dateOfBirth,
    required this.countryName,
    this.createdAt,
  });

  String get fullName => '$firstName $lastName'.trim();

  factory ApiMe.fromJson(Map<String, dynamic> json) => ApiMe(
        id: json['id'].toString(),
        firstName: json['firstName']?.toString() ?? '',
        lastName: json['lastName']?.toString() ?? '',
        email: json['email']?.toString() ?? '',
        dateOfBirth: json['dateOfBirth'] != null
            ? DateTime.tryParse(json['dateOfBirth'].toString())
            : null,
        countryName: json['countryName']?.toString() ?? '',
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'].toString())
            : null,
      );
}

/// Краткая карточка пользователя (Users API: GET /api/users).
class ApiUserSummary {
  final String id;
  final String firstName;
  final String lastName;
  final String countryName;

  ApiUserSummary({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.countryName,
  });

  String get fullName => '$firstName $lastName'.trim();

  factory ApiUserSummary.fromJson(Map<String, dynamic> json) => ApiUserSummary(
        id: json['id'].toString(),
        firstName: json['firstName']?.toString() ?? '',
        lastName: json['lastName']?.toString() ?? '',
        countryName: json['countryName']?.toString() ?? '',
      );
}

/// Курс валюты (Currencies API: GET /api/currencies/rates).
class ApiCurrencyRate {
  final String currencyCode;
  final double rateToUsd;
  final DateTime? updatedAt;

  ApiCurrencyRate({
    required this.currencyCode,
    required this.rateToUsd,
    this.updatedAt,
  });

  factory ApiCurrencyRate.fromJson(Map<String, dynamic> json) =>
      ApiCurrencyRate(
        currencyCode: json['currencyCode']?.toString() ?? '',
        rateToUsd: (json['rateToUsd'] as num?)?.toDouble() ?? 0.0,
        updatedAt: json['updatedAt'] != null
            ? DateTime.tryParse(json['updatedAt'].toString())
            : null,
      );
}

// ── API Client ───────────────────────────────────────────────────────────

class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  final http.Client _http = http.Client();

  Uri _u(String path) => Uri.parse('$kApiBaseUrl$path');

  Map<String, String> _headers({String? accessToken}) => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (accessToken != null) 'Authorization': 'Bearer $accessToken',
      };

  // ── Auth API ───────────────────────────────────────────────────────────

  /// POST /api/auth/register
  Future<AuthResult> register({
    required String firstName,
    required String lastName,
    required DateTime dateOfBirth,
    required String email,
    required int countryId,
    required String password,
    required String confirmPassword,
  }) async {
    final body = {
      'firstName': firstName,
      'lastName': lastName,
      'dateOfBirth': dateOfBirth.toIso8601String(),
      'email': email,
      'countryId': countryId,
      'password': password,
      'confirmPassword': confirmPassword,
    };

    final res = await _post('/api/auth/register', body);
    return AuthResult.fromJson(res);
  }

  /// POST /api/auth/login
  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    final res = await _post('/api/auth/login', {
      'email': email,
      'password': password,
    });
    return AuthResult.fromJson(res);
  }

  // ── Cards API ──────────────────────────────────────────────────────────

  /// GET /api/cards
  Future<List<ApiCard>> getCards(String accessToken) async {
    final res = await _get('/api/cards', accessToken: accessToken);
    if (res is List) {
      return res
          .map((e) => ApiCard.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    // Некоторые backend-ы оборачивают список в объект, например { items: [...] }.
    if (res is Map<String, dynamic>) {
      final items = res['items'] ?? res['data'] ?? res['cards'];
      if (items is List) {
        return items
            .map((e) => ApiCard.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    }
    return [];
  }

  /// GET /api/cards/{cardId}
  Future<ApiCard> getCardById(String accessToken, int cardId) async {
    final res = await _get('/api/cards/$cardId', accessToken: accessToken);
    return ApiCard.fromJson(res as Map<String, dynamic>);
  }

  /// POST /api/cards
  Future<void> createCard(
    String accessToken,
    int currencyId,
  ) async {
    await _postValue(
      '/api/cards',
      currencyId,
      accessToken: accessToken,
    );
  }

  // ── Wallets API ────────────────────────────────────────────────────────

  /// GET /api/wallets
  Future<List<ApiWallet>> getWallets(String accessToken) async {
    final res = await _get('/api/wallets', accessToken: accessToken);
    if (res is List) {
      return res
          .map((e) => ApiWallet.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    if (res is Map<String, dynamic>) {
      final items = res['items'] ?? res['data'] ?? res['wallets'];
      if (items is List) {
        return items
            .map((e) => ApiWallet.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    }
    return [];
  }

  /// GET /api/wallets/{walletId}
  Future<ApiWallet> getWalletById(String accessToken, String walletId) async {
    final res = await _get('/api/wallets/$walletId', accessToken: accessToken);
    return ApiWallet.fromJson(res as Map<String, dynamic>);
  }

  /// POST /api/wallets
  Future<ApiWallet> createWallet(String accessToken, int currencyId) async {
    final res = await _postValue(
      '/api/wallets',
      currencyId,
      accessToken: accessToken,
    );
    return ApiWallet.fromJson(res as Map<String, dynamic>);
  }

  // ── Transactions API ──────────────────────────────────────────────────

  /// GET /api/transactions
  Future<List<ApiTransaction>> getTransactions(String accessToken) async {
    final res = await _get('/api/transactions', accessToken: accessToken);
    if (res is List) {
      return res
          .map((e) => ApiTransaction.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    if (res is Map<String, dynamic>) {
      final items = res['items'] ?? res['data'] ?? res['transactions'];
      if (items is List) {
        return items
            .map((e) => ApiTransaction.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    }
    return [];
  }

  /// POST /api/transactions/sendMoney
  Future<ApiTransaction> sendMoney(
    String accessToken, {
    required String fromCardId,
    required String recipientCardNumber,
    required double amount,
  }) async {
    final res = await _post(
      '/api/transactions/sendMoney',
      {
        'fromCardId': fromCardId,
        'recipientCardNumber': recipientCardNumber,
        'amount': amount,
      },
      accessToken: accessToken,
    );
    return ApiTransaction.fromJson(res as Map<String, dynamic>);
  }

  /// POST /api/transactions/convert
  Future<void> convert(
    String accessToken, {
    required String walletId,
    required String cardId,
    required double amount,
    required ConversionDirection direction,
  }) async {
    print('=== CONVERT REQUEST ===');
    print({
      'walletId': walletId,
      'cardId': cardId,
      'amount': amount,
      'direction': direction.value,
    });

    final res = await _post(
      '/api/transactions/convert',
      {
        'walletId': walletId,
        'cardId': cardId,
        'amount': amount,
        'direction': direction.value,
      },
      accessToken: accessToken,
    );

    print('=== CONVERT RESPONSE ===');
    print(res);
  }

  /// POST /api/transactions/sendCrypto
  Future<ApiTransaction> sendCrypto(
    String accessToken, {
    required String fromWalletId,
    required String recipientAddress,
    required double amount,
  }) async {
    final res = await _post(
      '/api/transactions/sendCrypto',
      {
        'fromWalletId': fromWalletId,
        'recipientAddress': recipientAddress,
        'amount': amount,
      },
      accessToken: accessToken,
    );
    return ApiTransaction.fromJson(res as Map<String, dynamic>);
  }

  // ── Users API ──────────────────────────────────────────────────────────

  /// GET /api/users/me
  Future<ApiMe> getMyDetails(String accessToken) async {
    final res = await _get('/api/users/me', accessToken: accessToken);
    return ApiMe.fromJson(res as Map<String, dynamic>);
  }

  /// GET /api/users
  Future<List<ApiUserSummary>> getAllUsers(String accessToken) async {
    final res = await _get('/api/users', accessToken: accessToken);
    if (res is List) {
      return res
          .map((e) => ApiUserSummary.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    if (res is Map<String, dynamic>) {
      final items = res['items'] ?? res['data'] ?? res['users'];
      if (items is List) {
        return items
            .map((e) => ApiUserSummary.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    }
    return [];
  }

  // ── Currencies API ────────────────────────────────────────────────────

  /// GET /api/currencies/rates (без авторизации)
  Future<List<ApiCurrencyRate>> getCurrencyRates() async {
    final res = await _get('/api/currencies/rates');
    if (res is List) {
      return res
          .map((e) => ApiCurrencyRate.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    if (res is Map<String, dynamic>) {
      final items = res['items'] ?? res['data'] ?? res['rates'];
      if (items is List) {
        return items
            .map((e) => ApiCurrencyRate.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    }
    return [];
  }

  // ── Low-level helpers ─────────────────────────────────────────────────

  Future<dynamic> _get(String path, {String? accessToken}) async {
    try {
      final res = await _http
          .get(_u(path), headers: _headers(accessToken: accessToken))
          .timeout(const Duration(seconds: 15));
      return _handleResponse(res);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(
          'Network error: не удалось подключиться к серверу ($kApiBaseUrl). $e');
    }
  }

  Future<dynamic> _postValue(String path, dynamic value,
      {String? accessToken}) async {
    try {
      final url = _u(path);

      print('=== POST REQUEST ===');
      print('URL: $url');
      print('BODY: ${jsonEncode(value)}');
      print('HEADERS: ${_headers(accessToken: accessToken)}');

      final res = await _http
          .post(
            url,
            headers: _headers(accessToken: accessToken),
            body: jsonEncode(value),
          )
          .timeout(const Duration(seconds: 15));

      print('=== RESPONSE ===');
      print('STATUS: ${res.statusCode}');
      print('BODY: ${res.body}');

      return _handleResponse(res);
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> _post(String path, Map<String, dynamic> body,
      {String? accessToken}) async {
    try {
      final res = await _http
          .post(
            _u(path),
            headers: _headers(accessToken: accessToken),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));
      print('URL: ${_u(path)}');
      print('STATUS: ${res.statusCode}');
      print('BODY: ${res.body}');
      return _handleResponse(res);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException(
          'Network error: не удалось подключиться к серверу ($kApiBaseUrl). $e');
    }
  }

  dynamic _handleResponse(http.Response res) {
    final status = res.statusCode;
    dynamic decoded;
    try {
      decoded = res.body.isNotEmpty ? jsonDecode(res.body) : null;
    } catch (_) {
      decoded = null;
    }

    if (status >= 200 && status < 300) {
      return decoded;
    }

    // Пытаемся вытащить сообщение об ошибке из типичных полей backend-а.
    String message = 'Request failed ($status)';
    if (decoded is Map<String, dynamic>) {
      message = (decoded['message'] ??
              decoded['error'] ??
              decoded['title'] ??
              message)
          .toString();
      // Некоторые backend-ы (ASP.NET ValidationProblem) возвращают errors: { field: [msgs] }
      if (decoded['errors'] is Map) {
        final errors = decoded['errors'] as Map;
        final firstKey = errors.keys.isNotEmpty ? errors.keys.first : null;
        if (firstKey != null && errors[firstKey] is List) {
          final list = errors[firstKey] as List;
          if (list.isNotEmpty) message = list.first.toString();
        }
      }
    }
    throw ApiException(message, statusCode: status);
  }
}
