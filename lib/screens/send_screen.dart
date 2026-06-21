// lib/screens/send_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/wallet_provider.dart';
import '../providers/auth_provider.dart';
import 'login_screen.dart';
import '../utils/theme.dart';
import '../utils/formatters.dart';
import '../widgets/widgets.dart';
import '../models/models.dart';

class SendScreen extends StatefulWidget {
  const SendScreen({super.key});

  @override
  State<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen> {
  String _selectedAsset = 'USDT';
  final _amountController = TextEditingController();
  final _addressController = TextEditingController();

  @override
  void dispose() {
    _amountController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _send(BuildContext context, WalletProvider wallet) async {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      return;
    }
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      _showError(context, 'Enter a valid amount');
      return;
    }
    final address = _addressController.text.trim();
    if (address.isEmpty) {
      _showError(context, 'Enter a destination address');
      return;
    }

    final asset =
        _selectedAsset == 'USDT' ? CryptoAsset.usdt : CryptoAsset.usdc;
    final error = await wallet.sendCrypto(asset, amount, address);
    if (!context.mounted) return;

    if (error != null) {
      _showError(context, error);
    } else {
      _amountController.clear();
      _addressController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${formatCrypto(amount)} $_selectedAsset sent successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context);
    }
  }

  void _showError(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(msg),
          backgroundColor: AppColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletProvider>();
    final balance = _selectedAsset == 'USDT'
        ? wallet.usdtBalance
        : wallet.usdcBalance;
    final color = _selectedAsset == 'USDT'
        ? AppColors.usdtColor
        : AppColors.usdcColor;

    return Scaffold(
      appBar: AppBar(title: const Text('Send Crypto')),
      body: LoadingOverlay(
        isLoading: wallet.isLoading,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(title: 'Select Asset'),
              AssetSelector(
                selected: _selectedAsset,
                onChanged: (v) => setState(() => _selectedAsset = v),
                assets: const ['USDT', 'USDC'],
              ),
              const SizedBox(height: 8),

              // Balance
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  'Available: ${formatCrypto(balance)} $_selectedAsset',
                  style: TextStyle(
                      color: color,
                      fontSize: 13,
                      fontWeight: FontWeight.w500),
                ),
              ),

              const SizedBox(height: 20),
              const SectionHeader(title: 'Amount'),
              AmountInput(
                controller: _amountController,
                label: 'Amount to send',
                suffix: _selectedAsset,
              ),

              // Max button
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    _amountController.text = balance.toStringAsFixed(4);
                  },
                  child: const Text('MAX',
                      style: TextStyle(
                          color: AppColors.accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ),
              ),

              const SizedBox(height: 8),
              const SectionHeader(title: 'Destination Address'),
              TextField(
                controller: _addressController,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontFamily: 'monospace'),
                decoration: InputDecoration(
                  labelText: 'Wallet address',
                  hintText: _selectedAsset == 'USDT'
                      ? 'TRC-20 address (T...)'
                      : 'Polygon address (0x...)',
                  prefixIcon: const Icon(Icons.account_balance_wallet_outlined,
                      color: AppColors.textSecondary),
                ),
              ),

              const SizedBox(height: 32),

              // Network info
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Column(children: [
                  _InfoRow(
                      label: 'Network',
                      value: _selectedAsset == 'USDT' ? 'TRC-20' : 'Polygon'),
                  const SizedBox(height: 8),
                  _InfoRow(label: 'Network fee', value: 'Included'),
                  const SizedBox(height: 8),
                  _InfoRow(
                      label: 'Estimated time',
                      value: '1–5 minutes'),
                ]),
              ),

              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => _send(context, wallet),
                icon: const Icon(Icons.send_rounded),
                label: Text('Send $_selectedAsset'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.warning),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 13)),
        Text(value,
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500)),
      ],
    );
  }
}
