// lib/screens/transaction_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/models.dart';
import '../utils/theme.dart';
import '../utils/formatters.dart';

class TransactionDetailScreen extends StatelessWidget {
  final Transaction tx;

  const TransactionDetailScreen({super.key, required this.tx});

  @override
  Widget build(BuildContext context) {
    final config = _txConfig(tx);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ── Hero icon ───────────────────────────────────────────────────
            const SizedBox(height: 8),
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: config.color.withAlpha(30),
                shape: BoxShape.circle,
                border: Border.all(color: config.color.withAlpha(80), width: 2),
              ),
              child: Icon(config.icon, color: config.color, size: 34),
            ),
            const SizedBox(height: 14),

            // ── Type label ──────────────────────────────────────────────────
            Text(config.typeLabel,
                style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),

            // ── Primary amount ──────────────────────────────────────────────
            Text(
              config.primaryAmount,
              style: TextStyle(
                color: config.amountColor,
                fontSize: 32,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),

            // ── Secondary amount (convert / buy / swap) ──────────────────────
            if (tx.secondAmount != null && tx.secondCurrency != null) ...[
              const SizedBox(height: 4),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.arrow_downward_rounded,
                    color: AppColors.textSecondary, size: 14),
                const SizedBox(width: 4),
                Text(
                  config.secondaryAmount!,
                  style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 16,
                      fontWeight: FontWeight.w500),
                ),
              ]),
            ],

            const SizedBox(height: 6),
            Text(formatDate(tx.date),
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13)),

            // ── Status pill ─────────────────────────────────────────────────
            const SizedBox(height: 14),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.success.withAlpha(25),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.success.withAlpha(60)),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.check_circle_rounded,
                    color: AppColors.success, size: 14),
                SizedBox(width: 6),
                Text('Completed',
                    style: TextStyle(
                        color: AppColors.success,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ]),
            ),

            const SizedBox(height: 28),

            // ── Details card ────────────────────────────────────────────────
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _Row(label: 'Transaction ID', value: tx.id, mono: true, copyable: true),
                  _divider(),
                  _Row(label: 'Date', value: _fullDate(tx.date)),
                  _divider(),
                  _Row(label: 'Type', value: config.typeLabel),
                  _divider(),
                  _Row(label: 'Amount',
                      value: '${tx.amount} ${tx.currency}', mono: true),
                  if (tx.secondAmount != null) ...[
                    _divider(),
                    _Row(
                      label: _secondLabel(tx.type),
                      value: '${tx.secondAmount} ${tx.secondCurrency}',
                      mono: true,
                    ),
                  ],
                  if (tx.recipientName != null) ...[
                    _divider(),
                    _Row(label: 'Recipient', value: tx.recipientName!),
                  ],
                  if (tx.recipientCard != null) ...[
                    _divider(),
                    _Row(
                      label: 'Card / IBAN',
                      value: _maskFull(tx.recipientCard!),
                      mono: true,
                    ),
                  ],
                  if (tx.note != null && tx.note!.isNotEmpty) ...[
                    _divider(),
                    _Row(label: 'Note', value: tx.note!),
                  ],
                  if (tx.swapFromAsset != null) ...[
                    _divider(),
                    _Row(label: 'Swap',
                        value: '${tx.swapFromAsset} → ${tx.swapToAsset}'),
                  ],
                  if (tx.cardCurrency != null) ...[
                    _divider(),
                    _Row(label: 'Card', value: '${tx.cardCurrency} Virtual Card'),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Description ─────────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Description',
                      style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text(tx.description,
                      style: const TextStyle(
                          color: AppColors.textPrimary, fontSize: 14)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider() =>
      const Divider(height: 1, indent: 16, endIndent: 16);

  String _fullDate(DateTime dt) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}  $h:$m:$s';
  }

  String _secondLabel(TransactionType type) {
    switch (type) {
      case TransactionType.cryptoToFiat: return 'Received (fiat)';
      case TransactionType.fiatToCrypto: return 'Received (crypto)';
      case TransactionType.cryptoSwap:   return 'Received';
      default:                           return 'Second amount';
    }
  }

  String _maskFull(String input) {
    final clean = input.replaceAll(RegExp(r'\s'), '');
    if (clean.length <= 8) return input;
    return '${clean.substring(0, 4)} **** **** ${clean.substring(clean.length - 4)}';
  }

  _TxConfig _txConfig(Transaction tx) {
    switch (tx.type) {
      case TransactionType.cryptoReceived:
        return _TxConfig(
          icon: Icons.call_received_rounded,
          color: AppColors.success,
          typeLabel: 'Received',
          primaryAmount: '+${formatCrypto(tx.amount)} ${tx.currency}',
          amountColor: AppColors.success,
        );
      case TransactionType.cryptoSent:
        return _TxConfig(
          icon: Icons.send_rounded,
          color: AppColors.warning,
          typeLabel: 'Sent',
          primaryAmount: '-${formatCrypto(tx.amount)} ${tx.currency}',
          amountColor: AppColors.warning,
        );
      case TransactionType.cryptoToFiat:
        return _TxConfig(
          icon: Icons.swap_horiz_rounded,
          color: AppColors.accent,
          typeLabel: 'Converted to Fiat',
          primaryAmount: '-${formatCrypto(tx.amount)} ${tx.currency}',
          amountColor: AppColors.accent,
          secondaryAmount: '+${formatFiat(tx.secondAmount!, tx.secondCurrency!)}',
        );
      case TransactionType.fiatToCrypto:
        return _TxConfig(
          icon: Icons.add_card_rounded,
          color: AppColors.usdcColor,
          typeLabel: 'Bought Crypto',
          primaryAmount: '-${formatFiat(tx.amount, tx.currency)}',
          amountColor: AppColors.error,
          secondaryAmount: '+${formatCrypto(tx.secondAmount!)} ${tx.secondCurrency}',
        );
      case TransactionType.cardPayment:
      case TransactionType.cardPaymentUsd:
        return _TxConfig(
          icon: Icons.send_to_mobile_rounded,
          color: AppColors.error,
          typeLabel: 'Bank Transfer',
          primaryAmount: '-${formatFiat(tx.amount, tx.currency)}',
          amountColor: AppColors.error,
        );
      case TransactionType.cryptoSwap:
        return _TxConfig(
          icon: Icons.currency_exchange_rounded,
          color: AppColors.usdtColor,
          typeLabel: 'Crypto Swap',
          primaryAmount: '-${formatCrypto(tx.amount)} ${tx.currency}',
          amountColor: AppColors.usdtColor,
          secondaryAmount: '+${formatCrypto(tx.secondAmount!)} ${tx.secondCurrency}',
        );
      case TransactionType.cardTopup:
        return _TxConfig(
          icon: Icons.add_circle_outline,
          color: AppColors.success,
          typeLabel: 'Top-up',
          primaryAmount: '+${formatFiat(tx.amount, tx.currency)}',
          amountColor: AppColors.success,
        );
    }
  }
}

// ── Detail row ────────────────────────────────────────────────────────────────

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final bool mono;
  final bool copyable;

  const _Row({
    required this.label,
    required this.value,
    this.mono = false,
    this.copyable = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: mono ? 12 : 13,
                    fontWeight: FontWeight.w500,
                    fontFamily: mono ? 'monospace' : null),
                textAlign: TextAlign.end),
          ),
          if (copyable) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text('$label copied'),
                      duration: const Duration(seconds: 1)),
                );
              },
              child: const Icon(Icons.copy_outlined,
                  color: AppColors.textSecondary, size: 15),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Config helper ─────────────────────────────────────────────────────────────

class _TxConfig {
  final IconData icon;
  final Color color;
  final String typeLabel;
  final String primaryAmount;
  final Color amountColor;
  final String? secondaryAmount;

  const _TxConfig({
    required this.icon,
    required this.color,
    required this.typeLabel,
    required this.primaryAmount,
    required this.amountColor,
    this.secondaryAmount,
  });
}
