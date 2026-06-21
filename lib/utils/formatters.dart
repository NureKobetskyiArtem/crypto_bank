// lib/utils/formatters.dart

import 'package:intl/intl.dart';
import '../models/models.dart';

String formatCrypto(double amount, {int decimals = 4}) {
  if (amount == 0) return '0.00';
  return NumberFormat.currency(
    symbol: '',
    decimalDigits: decimals,
  ).format(amount).trim();
}

String formatFiat(double amount, String currency) {
  return NumberFormat.currency(
    symbol: currency == 'EUR' ? '€' : '\$',
    decimalDigits: 2,
  ).format(amount);
}

String formatDate(DateTime dt) {
  final now = DateTime.now();
  if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
    return 'Today ${DateFormat.Hm().format(dt)}';
  }
  if (dt.year == now.year) {
    return DateFormat('MMM d, HH:mm').format(dt);
  }
  return DateFormat('MMM d yyyy, HH:mm').format(dt);
}

String txTypeLabel(TransactionType type) {
  switch (type) {
    case TransactionType.cryptoReceived:
      return 'Received';
    case TransactionType.cryptoSent:
      return 'Sent';
    case TransactionType.cryptoToFiat:
      return 'Converted';
    case TransactionType.fiatToCrypto:
      return 'Bought';
    case TransactionType.cardPayment:
      return 'Transfer (EUR)';
    case TransactionType.cardPaymentUsd:
      return 'Transfer (USD)';
    case TransactionType.cryptoSwap:
      return 'Swap';
    case TransactionType.cardTopup:
      return 'Top-up';
  }
}

bool txIsIncoming(TransactionType type) {
  return type == TransactionType.cryptoReceived ||
      type == TransactionType.cardTopup;
}
