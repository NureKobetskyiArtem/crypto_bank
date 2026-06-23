// lib/providers/auth_provider.dart
//
// Авторизация через реальный backend (Auth API):
//   POST /api/auth/register
//   POST /api/auth/login
// accessToken и профиль пользователя сохраняются в SharedPreferences,
// чтобы сессия восстанавливалась при повторном запуске приложения.

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/api_client.dart';

enum AuthStatus { unknown, guest, authenticated }

class AuthProvider extends ChangeNotifier {
  AuthStatus _status = AuthStatus.unknown;
  UserProfile? _user;
  String? _error;
  bool _isLoading = false;

  final ApiClient _api = ApiClient.instance;

  AuthStatus get status => _status;
  UserProfile? get user => _user;
  String? get error => _error;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isGuest => _status == AuthStatus.guest || _status == AuthStatus.unknown;

  /// Токен для авторизованных запросов к Cards API и т.п.
  String? get accessToken => _user?.accessToken;

  AuthProvider() {
    _restoreSession();
  }

  // ── Session restore ───────────────────────────────────────────────────────

  Future<void> _restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString('auth_user');
    if (userJson != null) {
      try {
        _user = UserProfile.fromJson(jsonDecode(userJson));
        _status = AuthStatus.authenticated;
      } catch (_) {
        _status = AuthStatus.guest;
      }
    } else {
      _status = AuthStatus.guest;
    }
    notifyListeners();
  }

  // ── Register ──────────────────────────────────────────────────────────────
  //
  // POST /api/auth/register
  // body: firstName, lastName, dateOfBirth, email, countryId, password, confirmPassword

  Future<String?> register({
    required String firstName,
    required String lastName,
    required DateTime dateOfBirth,
    required String email,
    required String password,
    required String confirmPassword,
    int countryId = 1,
  }) async {
    _setLoading(true);

    final emailTrimmed = email.trim().toLowerCase();
    final firstTrimmed = firstName.trim();
    final lastTrimmed = lastName.trim();

    if (firstTrimmed.isEmpty) {
      _setLoading(false);
      return 'Enter your first name';
    }
    if (lastTrimmed.isEmpty) {
      _setLoading(false);
      return 'Enter your last name';
    }
    if (!_isValidEmail(emailTrimmed)) {
      _setLoading(false);
      return 'Enter a valid email address';
    }
    if (password.length < 6) {
      _setLoading(false);
      return 'Password must be at least 6 characters';
    }
    if (password != confirmPassword) {
      _setLoading(false);
      return 'Passwords do not match';
    }

    try {
      final result = await _api.register(
        firstName: firstTrimmed,
        lastName: lastTrimmed,
        dateOfBirth: dateOfBirth,
        email: emailTrimmed,
        countryId: countryId,
        password: password,
        confirmPassword: confirmPassword,
      );
      await _applyAuthResult(result, countryId: countryId);
      _setLoading(false);
      return null; // success
    } on ApiException catch (e) {
      _setLoading(false);
      return e.message;
    } catch (e) {
      _setLoading(false);
      return 'Unexpected error: $e';
    }
  }

  // ── Login ─────────────────────────────────────────────────────────────────
  //
  // POST /api/auth/login
  // body: email, password

  Future<String?> login({
    required String email,
    required String password,
  }) async {
    _setLoading(true);

    final emailTrimmed = email.trim().toLowerCase();

    if (!_isValidEmail(emailTrimmed)) {
      _setLoading(false);
      return 'Enter a valid email address';
    }
    if (password.isEmpty) {
      _setLoading(false);
      return 'Enter your password';
    }

    try {
      final result = await _api.login(email: emailTrimmed, password: password);
      await _applyAuthResult(result);
      _setLoading(false);
      return null; // success
    } on ApiException catch (e) {
      _setLoading(false);
      return e.message;
    } catch (e) {
      _setLoading(false);
      return 'Unexpected error: $e';
    }
  }

  // ── Users API ─────────────────────────────────────────────────────────────
  //
  // GET /api/users/me — обновляет email/имя/дату рождения/страну из backend
  // (полезно, если данные пользователя изменились на сервере).

  Future<ApiMe?> fetchMyDetails() async {
    final token = accessToken;
    if (token == null || token.isEmpty) return null;
    try {
      final me = await _api.getMyDetails(token);
      if (_user != null) {
        _user = UserProfile(
          id: me.id,
          email: me.email,
          firstName: me.firstName,
          lastName: me.lastName,
          countryId: _user!.countryId,
          createdAt: me.createdAt ?? _user!.createdAt,
          accessToken: _user!.accessToken,
        );
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_user', jsonEncode(_user!.toJson()));
        notifyListeners();
      }
      return me;
    } catch (_) {
      return null;
    }
  }

  /// GET /api/users — список всех пользователей (например, для выбора
  /// получателя перевода).
  Future<List<ApiUserSummary>> fetchAllUsers() async {
    final token = accessToken;
    if (token == null || token.isEmpty) return [];
    try {
      return await _api.getAllUsers(token);
    } catch (_) {
      return [];
    }
  }

  // ── Logout ────────────────────────────────────────────────────────────────

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_user');
    _user = null;
    _status = AuthStatus.guest;
    notifyListeners();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<void> _applyAuthResult(AuthResult result, {int? countryId}) async {
    final profile = UserProfile(
      id: result.user.id,
      email: result.user.email,
      firstName: result.user.firstName,
      lastName: result.user.lastName,
      countryId: countryId ?? 1,
      createdAt: DateTime.now(),
      accessToken: result.accessToken,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_user', jsonEncode(profile.toJson()));
    _user = profile;
    _status = AuthStatus.authenticated;
    notifyListeners();
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
        .hasMatch(email);
  }

  void _setLoading(bool val) {
    _isLoading = val;
    _error = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
