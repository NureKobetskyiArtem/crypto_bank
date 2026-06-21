// lib/screens/profile_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/rates_provider.dart';
import '../services/api_enums.dart';
import '../utils/theme.dart';
import '../utils/formatters.dart';
import 'login_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final rates = context.watch<RatesProvider>();

    if (!auth.isAuthenticated) {
      return _GuestPrompt();
    }

    final user = auth.user!;
    final initials = user.displayName
        .split(' ')
        .take(2)
        .map((e) => e.isNotEmpty ? e[0].toUpperCase() : '')
        .join();

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              const Text('Profile',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w800)),

              const SizedBox(height: 24),

              // Avatar + name
              Center(
                child: Column(children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.accent, Color(0xFF651FFF)],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(initials,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(user.displayName,
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(user.email,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(CountryId.fromId(user.countryId).label,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                ]),
              ),

              const SizedBox(height: 28),

              // Exchange rates section
              _SectionTitle('Live Exchange Rates'),
              _RatesCard(rates: rates),

              const SizedBox(height: 20),

              // App info
              _SectionTitle('App'),
              _MenuItem(
                icon: Icons.info_outline,
                label: 'Version 1.0.0',
                onTap: null,
                trailing: const Text('MVP',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 13)),
              ),

              const SizedBox(height: 24),

              // Logout
              OutlinedButton.icon(
                onPressed: () => _logout(context, auth),
                icon: const Icon(Icons.logout_rounded,
                    color: AppColors.error),
                label: const Text('Sign Out',
                    style: TextStyle(color: AppColors.error)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.error),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _logout(BuildContext context, AuthProvider auth) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        title: const Text('Sign Out',
            style: TextStyle(color: AppColors.textPrimary)),
        content: const Text('Are you sure you want to sign out?',
            style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Sign Out',
                  style: TextStyle(color: AppColors.error))),
        ],
      ),
    );
    if (confirm == true) await auth.logout();
  }
}

// ── Guest prompt ──────────────────────────────────────────────────────────────

class _GuestPrompt extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.divider),
                ),
                child: const Icon(Icons.person_outline,
                    color: AppColors.textSecondary, size: 40),
              ),
              const SizedBox(height: 20),
              const Text('You are not signed in',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              const Text(
                'Sign in to access your profile, manage security settings, and more.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    height: 1.5),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const LoginScreen())),
                icon: const Icon(Icons.login_rounded),
                label: const Text('Sign In'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Rates Card ────────────────────────────────────────────────────────────────

class _RatesCard extends StatelessWidget {
  final RatesProvider rates;
  const _RatesCard({required this.rates});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(children: [
        if (rates.isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Row(children: [
              SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.accent)),
              SizedBox(width: 8),
              Text('Updating rates...',
                  style: TextStyle(
                      color: AppColors.textSecondary, fontSize: 13)),
            ]),
          )
        else if (rates.lastFetch != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Last updated',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 11)),
                Text(formatDate(rates.lastFetch!),
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 11)),
              ],
            ),
          ),
        if (rates.hasError)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(rates.errorMsg,
                style: const TextStyle(
                    color: AppColors.warning, fontSize: 12)),
          ),
        _RateRow('USDT → EUR', rates.usdtToEur, suffix: 'EUR'),
        _RateRow('USDC → EUR', rates.usdcToEur, suffix: 'EUR'),
        _RateRow('USD → EUR', rates.usdToEur, suffix: 'EUR'),
        _RateRow('USD → GBP', rates.usdToGbp, suffix: 'GBP'),
        _RateRow('USD → UAH', rates.usdToUah, suffix: 'UAH'),
        _RateRow('BTC → USD', rates.btcToUsd, suffix: 'USD', compact: true),
        _RateRow('ETH → USD', rates.ethToUsd, suffix: 'USD', compact: true),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => rates.fetchRates(),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.refresh_rounded,
                color: AppColors.accent, size: 16),
            const SizedBox(width: 4),
            const Text('Refresh',
                style: TextStyle(color: AppColors.accent, fontSize: 13)),
          ]),
        ),
      ]),
    );
  }
}

class _RateRow extends StatelessWidget {
  final String label;
  final double value;
  final String suffix;
  final bool compact;
  const _RateRow(this.label, this.value,
      {required this.suffix, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final display = compact
        ? '\$${value >= 1000 ? (value / 1000).toStringAsFixed(1) + "k" : value.toStringAsFixed(0)}'
        : value.toStringAsFixed(4);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 13)),
        Text('$display $suffix',
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text,
            style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5)),
      );
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Widget? trailing;
  const _MenuItem(
      {required this.icon,
      required this.label,
      required this.onTap,
      this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.textSecondary, size: 18),
        ),
        title: Text(label,
            style: const TextStyle(
                color: AppColors.textPrimary, fontSize: 14)),
        trailing: trailing ??
            (onTap != null
                ? const Icon(Icons.chevron_right_rounded,
                    color: AppColors.textSecondary)
                : null),
        onTap: onTap,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
