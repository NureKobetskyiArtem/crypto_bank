// lib/screens/receive_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/wallet_provider.dart';
import '../providers/auth_provider.dart';
import 'login_screen.dart';
import '../utils/theme.dart';
import '../utils/formatters.dart';
import '../widgets/widgets.dart';
import '../models/models.dart';

class ReceiveScreen extends StatefulWidget {
  const ReceiveScreen({super.key});

  @override
  State<ReceiveScreen> createState() => _ReceiveScreenState();
}

class _ReceiveScreenState extends State<ReceiveScreen> {
  String _selectedAsset = 'USDT';

  // For demo: simulate incoming payment
  final _amountController = TextEditingController();

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletProvider>();
    final asset =
        _selectedAsset == 'USDT' ? CryptoAsset.usdt : CryptoAsset.usdc;
    final address =
        _selectedAsset == 'USDT' ? wallet.usdtAddress : wallet.usdcAddress;
    final color = _selectedAsset == 'USDT'
        ? AppColors.usdtColor
        : AppColors.usdcColor;

    return Scaffold(
      appBar: AppBar(title: const Text('Receive Crypto')),
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
              const SizedBox(height: 24),

              // Address
              const SectionHeader(title: 'Your Deposit Address'),
              AddressRow(
                  label: '${asset.symbol} (${asset.network})',
                  address: address,
                  color: color),

              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.warning.withAlpha(20),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.warning.withAlpha(60)),
                ),
                child: Row(children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: AppColors.warning, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Only send ${asset.symbol} (${asset.network}) to this address.',
                      style: const TextStyle(
                          color: AppColors.warning, fontSize: 12),
                    ),
                  ),
                ]),
              ),

              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 16),

              // Demo: simulate incoming tx
              const SectionHeader(title: '🧪 Simulate Incoming Payment'),
              const Text(
                'Use this to test receiving crypto in the demo.',
                style:
                    TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 12),
              AmountInput(
                controller: _amountController,
                label: 'Amount',
                suffix: _selectedAsset,
                hint: '100.00',
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () async {
                  final auth = context.read<AuthProvider>();
                  if (!auth.isAuthenticated) {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
                    return;
                  }
                  final amount =
                      double.tryParse(_amountController.text.trim());
                  if (amount == null || amount <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Enter a valid amount')),
                    );
                    return;
                  }
                  await wallet.simulateReceive(asset, amount);
                  if (!context.mounted) return;
                  _amountController.clear();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          '${formatCrypto(amount)} $_selectedAsset received!'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                },
                icon: const Icon(Icons.call_received_rounded),
                label: Text('Simulate Receiving $_selectedAsset'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
