// lib/screens/buy_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/wallet_provider.dart';
import '../providers/auth_provider.dart';
import 'login_screen.dart';
import '../utils/theme.dart';
import '../utils/formatters.dart';
import '../widgets/widgets.dart';
import '../models/models.dart';

class BuyScreen extends StatefulWidget {
  const BuyScreen({super.key});

  @override
  State<BuyScreen> createState() => _BuyScreenState();
}

class _BuyScreenState extends State<BuyScreen> {
  String _selectedAsset = 'USDT';
  String _sourceCurrency = 'EUR';
  final _amountController = TextEditingController();
  double _previewCrypto = 0;
  double _previewFee = 0;

  @override
  void initState() {
    super.initState();
    _amountController.addListener(_updatePreview);
  }

  @override
  void dispose() {
    _amountController.removeListener(_updatePreview);
    _amountController.dispose();
    super.dispose();
  }

  void _updatePreview() {
    final wallet = context.read<WalletProvider>();
    final fiatAmount = double.tryParse(_amountController.text) ?? 0;
    final fee = fiatAmount * wallet.buyFeePercent / 100;
    final net = fiatAmount - fee;
    final asset =
        _selectedAsset == 'USDT' ? CryptoAsset.usdt : CryptoAsset.usdc;
    final rate = wallet.fiatRate(asset, _sourceCurrency);
    setState(() {
      _previewFee = fee;
      _previewCrypto = rate > 0 ? net / rate : 0;
    });
  }

  Future<void> _buy() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => const LoginScreen()));
      return;
    }
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      _err('Enter a valid amount');
      return;
    }
    final wallet = context.read<WalletProvider>();
    final asset =
        _selectedAsset == 'USDT' ? CryptoAsset.usdt : CryptoAsset.usdc;
    final error = await wallet.buyCryptoWithCard(asset, amount, _sourceCurrency,
        accessToken: auth.accessToken);
    if (!mounted) return;
    if (error != null) {
      _err(error);
    } else {
      _amountController.clear();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            '${formatCrypto(_previewCrypto)} $_selectedAsset purchased!'),
        backgroundColor: AppColors.success,
      ));
      Navigator.pop(context);
    }
  }

  void _err(String msg) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.error));

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletProvider>();
    final sourceBalance = _sourceCurrency == 'EUR'
        ? wallet.eurBalance
        : wallet.usdBalance;

    return Scaffold(
      appBar: AppBar(title: const Text('Buy Crypto')),
      body: LoadingOverlay(
        isLoading: wallet.isLoading,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(title: 'Select Asset to Buy'),
              AssetSelector(
                selected: _selectedAsset,
                onChanged: (v) {
                  setState(() => _selectedAsset = v);
                  _updatePreview();
                },
                assets: const ['USDT', 'USDC'],
              ),

              const SizedBox(height: 20),

              const SectionHeader(title: 'Pay With'),
              AssetSelector(
                selected: _sourceCurrency,
                onChanged: (v) {
                  setState(() => _sourceCurrency = v);
                  _updatePreview();
                },
                assets: const ['EUR', 'USD'],
              ),
              const SizedBox(height: 6),
              Text(
                  'Balance: ${formatFiat(sourceBalance, _sourceCurrency)}',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 13)),

              const SizedBox(height: 20),

              SectionHeader(title: 'Amount ($_sourceCurrency)'),
              AmountInput(
                controller: _amountController,
                label: 'Amount to spend',
                suffix: _sourceCurrency,
                hint: '100.00',
              ),

              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [50.0, 100.0, 200.0, 500.0].map((v) {
                  final sym = _sourceCurrency == 'EUR' ? '€' : '\$';
                  return ActionChip(
                    label: Text('$sym${v.toInt()}'),
                    onPressed: () =>
                        _amountController.text = v.toStringAsFixed(0),
                    backgroundColor: AppColors.surface,
                    labelStyle: const TextStyle(
                        color: AppColors.textPrimary, fontSize: 13),
                    side: const BorderSide(color: AppColors.divider),
                  );
                }).toList(),
              ),

              const SizedBox(height: 20),

              if (_previewCrypto > 0) ...[
                _BuyPreview(
                  fiatAmount:
                      double.tryParse(_amountController.text) ?? 0,
                  fee: _previewFee,
                  crypto: _previewCrypto,
                  asset: _selectedAsset,
                  currency: _sourceCurrency,
                  feePercent: wallet.buyFeePercent,
                ),
                const SizedBox(height: 20),
              ],

              ElevatedButton.icon(
                onPressed: _buy,
                icon: const Icon(Icons.add_card_rounded),
                label: Text('Buy $_selectedAsset'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.usdcColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BuyPreview extends StatelessWidget {
  final double fiatAmount;
  final double fee;
  final double crypto;
  final String asset;
  final String currency;
  final double feePercent;

  const _BuyPreview({
    required this.fiatAmount,
    required this.fee,
    required this.crypto,
    required this.asset,
    required this.currency,
    required this.feePercent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(children: [
        _R('You spend', formatFiat(fiatAmount, currency)),
        const Divider(height: 18),
        _R('Service fee ($feePercent%)', '-${formatFiat(fee, currency)}'),
        const Divider(height: 18),
        _R('You receive', '≈ ${formatCrypto(crypto)} $asset',
            highlight: true),
      ]),
    );
  }
}

class _R extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;
  const _R(this.label, this.value, {this.highlight = false});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13)),
          Text(value,
              style: TextStyle(
                  color: highlight ? AppColors.success : AppColors.textPrimary,
                  fontSize: highlight ? 15 : 13,
                  fontWeight:
                      highlight ? FontWeight.w700 : FontWeight.w500)),
        ],
      );
}
