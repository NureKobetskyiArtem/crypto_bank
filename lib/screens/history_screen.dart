// lib/screens/history_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/wallet_provider.dart';
import '../providers/auth_provider.dart';
import '../utils/theme.dart';
import '../utils/formatters.dart';
import '../models/models.dart';
import 'transaction_detail_screen.dart';
import 'login_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  TransactionType? _filter;

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletProvider>();
    final auth = context.watch<AuthProvider>();

    // Блокировка для гостей
    if (!auth.isAuthenticated) {
      return _LockedScreen(
        onSignIn: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const LoginScreen())),
      );
    }

    final all = wallet.transactions;
    final filtered =
        _filter == null ? all : all.where((t) => t.type == _filter).toList();

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Transaction',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 13)),
                  const Text('History',
                      style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 24,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 14),
                  // Filter chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(children: [
                      _Chip(
                          label: 'All',
                          selected: _filter == null,
                          onTap: () => setState(() => _filter = null)),
                      const SizedBox(width: 7),
                      ...TransactionType.values.map((t) => Padding(
                            padding: const EdgeInsets.only(right: 7),
                            child: _Chip(
                                label: txTypeLabel(t),
                                selected: _filter == t,
                                onTap: () =>
                                    setState(() => _filter = t)),
                          )),
                    ]),
                  ),
                  const SizedBox(height: 8),
                  Text('${filtered.length} transactions',
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),

            const SizedBox(height: 8),

            Expanded(
              child: filtered.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.history_outlined,
                              color: AppColors.textSecondary, size: 48),
                          SizedBox(height: 8),
                          Text('No transactions',
                              style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 15)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final tx = filtered[index];
                        return _TxCard(
                          tx: tx,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  TransactionDetailScreen(tx: tx),
                            ),
                          ),
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

// ── Locked screen ─────────────────────────────────────────────────────────────

class _LockedScreen extends StatelessWidget {
  final VoidCallback onSignIn;
  const _LockedScreen({required this.onSignIn});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: const Icon(Icons.lock_outline,
                      color: AppColors.textSecondary, size: 34),
                ),
                const SizedBox(height: 20),
                const Text('History is private',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                const Text(
                  'Sign in to view your transaction history.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                      height: 1.5),
                ),
                const SizedBox(height: 28),
                ElevatedButton.icon(
                  onPressed: onSignIn,
                  icon: const Icon(Icons.login_rounded),
                  label: const Text('Sign In'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Filter chip ───────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Chip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? AppColors.accent : AppColors.divider),
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? Colors.white : AppColors.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w500)),
      ),
    );
  }
}

// ── Transaction card ──────────────────────────────────────────────────────────

class _TxCard extends StatelessWidget {
  final Transaction tx;
  final VoidCallback onTap;
  const _TxCard({required this.tx, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cfg = _config(tx);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.cardBg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: cfg.color.withAlpha(30),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(cfg.icon, color: cfg.color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cfg.typeLabel,
                    style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14)),
                const SizedBox(height: 2),
                Text(tx.description,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(formatDate(tx.date),
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 11)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(cfg.amountStr,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                      color: cfg.amountColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.divider, size: 16),
            ],
          ),
        ]),
      ),
    );
  }

  _TxCfg _config(Transaction tx) {
    switch (tx.type) {
      case TransactionType.cryptoReceived:
        return _TxCfg(
          icon: Icons.call_received_rounded,
          color: AppColors.success,
          typeLabel: 'Received',
          amountStr: '+${formatCrypto(tx.amount)} ${tx.currency}',
          amountColor: AppColors.success,
        );
      case TransactionType.cryptoSent:
        return _TxCfg(
          icon: Icons.send_rounded,
          color: AppColors.warning,
          typeLabel: 'Sent',
          amountStr: '-${formatCrypto(tx.amount)} ${tx.currency}',
          amountColor: AppColors.warning,
        );
      case TransactionType.cryptoToFiat:
        return _TxCfg(
          icon: Icons.swap_horiz_rounded,
          color: AppColors.accent,
          typeLabel: 'Converted',
          amountStr:
              '-${formatCrypto(tx.amount)} ${tx.currency}\n+${formatFiat(tx.secondAmount!, tx.secondCurrency!)}',
          amountColor: AppColors.accentLight,
        );
      case TransactionType.fiatToCrypto:
        return _TxCfg(
          icon: Icons.add_card_rounded,
          color: AppColors.usdcColor,
          typeLabel: 'Bought',
          amountStr:
              '-${formatFiat(tx.amount, tx.currency)}\n+${formatCrypto(tx.secondAmount!)} ${tx.secondCurrency}',
          amountColor: AppColors.usdcColor,
        );
      case TransactionType.cardPayment:
      case TransactionType.cardPaymentUsd:
        return _TxCfg(
          icon: Icons.send_to_mobile_rounded,
          color: AppColors.error,
          typeLabel: 'Transfer',
          amountStr: '-${formatFiat(tx.amount, tx.currency)}',
          amountColor: AppColors.error,
        );
      case TransactionType.cryptoSwap:
        return _TxCfg(
          icon: Icons.currency_exchange_rounded,
          color: AppColors.usdtColor,
          typeLabel: 'Swap',
          amountStr:
              '-${formatCrypto(tx.amount)} ${tx.currency}\n+${formatCrypto(tx.secondAmount!)} ${tx.secondCurrency}',
          amountColor: AppColors.usdtColor,
        );
      case TransactionType.cardTopup:
        return _TxCfg(
          icon: Icons.add_circle_outline,
          color: AppColors.success,
          typeLabel: 'Top-up',
          amountStr: '+${formatFiat(tx.amount, tx.currency)}',
          amountColor: AppColors.success,
        );
    }
  }
}

class _TxCfg {
  final IconData icon;
  final Color color;
  final String typeLabel;
  final String amountStr;
  final Color amountColor;
  const _TxCfg({
    required this.icon,
    required this.color,
    required this.typeLabel,
    required this.amountStr,
    required this.amountColor,
  });
}
