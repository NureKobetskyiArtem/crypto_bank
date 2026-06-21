// lib/widgets/auth_guard.dart
//
// Виджет-обёртка: показывает баннер "войдите чтобы продолжить"
// поверх заблокированного UI когда пользователь гость.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../utils/theme.dart';
import '../screens/login_screen.dart';

/// Оборачивает любой виджет-действие.
/// Если пользователь не авторизован — показывает bottom sheet с предложением войти.
class AuthGuard extends StatelessWidget {
  final Widget child;
  final bool blockCompletely; // если true — скрывает child

  const AuthGuard({
    super.key,
    required this.child,
    this.blockCompletely = false,
  });

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (auth.isAuthenticated) return child;

    if (blockCompletely) {
      return _AuthWall();
    }

    // Полупрозрачная обёртка
    return Stack(
      children: [
        IgnorePointer(child: Opacity(opacity: 0.4, child: child)),
        Positioned.fill(
          child: GestureDetector(
            onTap: () => showAuthPrompt(context),
            child: Container(color: Colors.transparent),
          ),
        ),
      ],
    );
  }

  static void showAuthPrompt(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.cardBg,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.accent.withAlpha(30),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_rounded,
                  color: AppColors.accent, size: 24),
            ),
            const SizedBox(height: 16),
            const Text('Sign in required',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text(
              'You need to be signed in to perform transactions. '
              'Browsing the app is always free.',
              textAlign: TextAlign.center,
              style:
                  TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()));
              },
              icon: const Icon(Icons.login_rounded),
              label: const Text('Sign In'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Continue browsing',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthWall extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_rounded,
                color: AppColors.textSecondary, size: 48),
            const SizedBox(height: 16),
            const Text('Sign in required',
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text(
              'This section is only available to signed-in users.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const LoginScreen())),
              icon: const Icon(Icons.login_rounded),
              label: const Text('Sign In'),
            ),
          ],
        ),
      ),
    );
  }
}
