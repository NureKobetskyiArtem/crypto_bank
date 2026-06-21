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
  Future<ApiCard> getCardById(String accessToken, String cardId) async {
    final res = await _get('/api/cards/$cardId', accessToken: accessToken);
    return ApiCard.fromJson(res as Map<String, dynamic>);
  }

  /// POST /api/cards
  Future<ApiCard> createCard(String accessToken, int currencyId) async {
    final res = await _post(
      '/api/cards',
      {'currencyId': currencyId},
      accessToken: accessToken,
    );
    return ApiCard.fromJson(res as Map<String, dynamic>);
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
      throw ApiException('Network error: не удалось подключиться к серверу ($kApiBaseUrl). $e');
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
      return _handleResponse(res);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Network error: не удалось подключиться к серверу ($kApiBaseUrl). $e');
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
