// lib/screens/convert_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/wallet_provider.dart';
import '../providers/auth_provider.dart';
import 'login_screen.dart';
import '../utils/theme.dart';
import '../utils/formatters.dart';
import '../widgets/widgets.dart';
import '../models/models.dart';

class ConvertScreen extends StatefulWidget {
  const ConvertScreen({super.key});

  @override
  State<ConvertScreen> createState() => _ConvertScreenState();
}

class _ConvertScreenState extends State<ConvertScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Convert'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Crypto → Fiat'),
            Tab(text: 'Crypto Swap'),
          ],
          indicator: const UnderlineTabIndicator(
            borderSide: BorderSide(color: AppColors.accent, width: 2),
          ),
          labelColor: AppColors.accent,
          unselectedLabelColor: AppColors.textSecondary,
          dividerColor: AppColors.divider,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _CryptoToFiatTab(),
          _CryptoSwapTab(),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Tab 1: Crypto → Fiat (EUR or USD)
// ═══════════════════════════════════════════════════════════════════════════════

class _CryptoToFiatTab extends StatefulWidget {
  const _CryptoToFiatTab();

  @override
  State<_CryptoToFiatTab> createState() => _CryptoToFiatTabState();
}

class _CryptoToFiatTabState extends State<_CryptoToFiatTab>
    with AutomaticKeepAliveClientMixin {
  String _fromAsset = 'USDT';
  String _toCurrency = 'EUR';
  final _amountCtrl = TextEditingController();
  double _previewNet = 0;
  double _previewFee = 0;
  double _previewRate = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _amountCtrl.addListener(_updatePreview);
  }

  @override
  void dispose() {
    _amountCtrl.removeListener(_updatePreview);
    _amountCtrl.dispose();
    super.dispose();
  }

  void _updatePreview() {
    final wallet = context.read<WalletProvider>();
    final amount = double.tryParse(_amountCtrl.text) ?? 0;
    final asset = _fromAsset == 'USDT' ? CryptoAsset.usdt : CryptoAsset.usdc;
    final rate = wallet.fiatRate(asset, _toCurrency);
    final gross = amount * rate;
    final fee = gross * wallet.exchangeFeePercent / 100;
    setState(() {
      _previewRate = rate;
      _previewFee = fee;
      _previewNet = gross - fee;
    });
  }

  Future<void> _convert() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => const LoginScreen()));
      return;
    }
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      _err('Enter a valid amount');
      return;
    }
    final wallet = context.read<WalletProvider>();
    final asset = _fromAsset == 'USDT' ? CryptoAsset.usdt : CryptoAsset.usdc;
    final error = await wallet.convertCryptoToFiat(asset, amount, _toCurrency,
        accessToken: auth.accessToken);
    if (!mounted) return;
    if (error != null) {
      _err(error);
    } else {
      _amountCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            '${formatFiat(_previewNet, _toCurrency)} added to $_toCurrency balance!'),
        backgroundColor: AppColors.success,
      ));
      Navigator.pop(context);
    }
  }

  void _err(String msg) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.error));

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final wallet = context.watch<WalletProvider>();
    final balance = _fromAsset == 'USDT'
        ? wallet.usdtBalance
        : wallet.usdcBalance;
    final toBalance =
        _toCurrency == 'EUR' ? wallet.eurBalance : wallet.usdBalance;

    return LoadingOverlay(
      isLoading: wallet.isLoading,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // From asset
          const SectionHeader(title: 'From (Crypto)'),
          AssetSelector(
            selected: _fromAsset,
            onChanged: (v) {
              setState(() => _fromAsset = v);
              _updatePreview();
            },
            assets: const ['USDT', 'USDC'],
          ),
          const SizedBox(height: 6),
          Text('Available: ${formatCrypto(balance)} $_fromAsset',
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13)),

          const SizedBox(height: 20),

          // To currency
          const SectionHeader(title: 'To (Fiat)'),
          AssetSelector(
            selected: _toCurrency,
            onChanged: (v) {
              setState(() => _toCurrency = v);
              _updatePreview();
            },
            assets: const ['EUR', 'USD'],
          ),
          const SizedBox(height: 6),
          Text(
              'Current $_toCurrency balance: ${formatFiat(toBalance, _toCurrency)}',
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13)),

          const SizedBox(height: 20),

          // Amount
          const SectionHeader(title: 'Amount'),
          AmountInput(
            controller: _amountCtrl,
            label: 'Amount to convert',
            suffix: _fromAsset,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () =>
                  _amountCtrl.text = balance.toStringAsFixed(4),
              child: const Text('MAX',
                  style: TextStyle(
                      color: AppColors.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ),
          ),

          // Preview
          if (_previewNet > 0) ...[
            _Preview(
              fromAsset: _fromAsset,
              toCurrency: _toCurrency,
              rate: _previewRate,
              fee: _previewFee,
              net: _previewNet,
              feePercent: wallet.exchangeFeePercent,
            ),
            const SizedBox(height: 16),
          ],

          // Arrow
          Center(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.accent.withAlpha(25),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.accent.withAlpha(70)),
              ),
              child: const Icon(Icons.arrow_downward_rounded,
                  color: AppColors.accent, size: 22),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              '$_toCurrency Balance: ${formatFiat(toBalance, _toCurrency)}',
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13),
            ),
          ),
          const SizedBox(height: 24),

          ElevatedButton.icon(
            onPressed: _convert,
            icon: const Icon(Icons.swap_horiz_rounded),
            label: Text('Convert $_fromAsset → $_toCurrency'),
          ),
        ]),
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  final String fromAsset;
  final String toCurrency;
  final double rate;
  final double fee;
  final double net;
  final double feePercent;

  const _Preview({
    required this.fromAsset,
    required this.toCurrency,
    required this.rate,
    required this.fee,
    required this.net,
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
        _R('Rate', '1 $fromAsset = ${rate.toStringAsFixed(4)} $toCurrency'),
        const Divider(height: 18),
        _R('Service fee ($feePercent%)', '-${formatFiat(fee, toCurrency)}'),
        const Divider(height: 18),
        _R('You receive', formatFiat(net, toCurrency), highlight: true),
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

// ═══════════════════════════════════════════════════════════════════════════════
// Tab 2: Crypto Swap (USDT ↔ USDC)
// ═══════════════════════════════════════════════════════════════════════════════

class _CryptoSwapTab extends StatefulWidget {
  const _CryptoSwapTab();

  @override
  State<_CryptoSwapTab> createState() => _CryptoSwapTabState();
}

class _CryptoSwapTabState extends State<_CryptoSwapTab>
    with AutomaticKeepAliveClientMixin {
  String _fromAsset = 'USDT';
  String _toAsset = 'USDC';
  final _amountCtrl = TextEditingController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _amountCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  void _flip() => setState(() {
        final tmp = _fromAsset;
        _fromAsset = _toAsset;
        _toAsset = tmp;
      });

  CryptoAsset get _fromCryptoAsset =>
      _fromAsset == 'USDT' ? CryptoAsset.usdt : CryptoAsset.usdc;
  CryptoAsset get _toCryptoAsset =>
      _toAsset == 'USDT' ? CryptoAsset.usdt : CryptoAsset.usdc;

  Future<void> _swap() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => const LoginScreen()));
      return;
    }
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      _err('Enter a valid amount');
      return;
    }
    final wallet = context.read<WalletProvider>();
    final error =
        await wallet.swapCrypto(_fromCryptoAsset, _toCryptoAsset, amount);
    if (!mounted) return;
    if (error != null) {
      _err(error);
    } else {
      _amountCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Swapped $amount $_fromAsset → $_toAsset!'),
        backgroundColor: AppColors.success,
      ));
      Navigator.pop(context);
    }
  }

  void _err(String msg) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.error));

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final wallet = context.watch<WalletProvider>();
    final fromBal = _fromAsset == 'USDT'
        ? wallet.usdtBalance
        : wallet.usdcBalance;
    final toBal = _toAsset == 'USDT'
        ? wallet.usdtBalance
        : wallet.usdcBalance;
    final amount = double.tryParse(_amountCtrl.text) ?? 0;
    final fee = amount * wallet.swapFeePercent / 100;
    final received = amount > 0 ? amount - fee : 0.0;

    return LoadingOverlay(
      isLoading: wallet.isLoading,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // From
          _FieldLabel('From'),
          const SizedBox(height: 8),
          _AssetBox(
            asset: _fromAsset,
            balance: fromBal,
            color: _fromAsset == 'USDT'
                ? AppColors.usdtColor
                : AppColors.usdcColor,
          ),

          // Flip button
          const SizedBox(height: 8),
          Center(
            child: GestureDetector(
              onTap: _flip,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.accent.withAlpha(25),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.accent.withAlpha(70)),
                ),
                child: const Icon(Icons.swap_vert_rounded,
                    color: AppColors.accent, size: 22),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // To
          _FieldLabel('To'),
          const SizedBox(height: 8),
          _AssetBox(
            asset: _toAsset,
            balance: toBal,
            color: _toAsset == 'USDT'
                ? AppColors.usdtColor
                : AppColors.usdcColor,
          ),

          const SizedBox(height: 20),

          // Amount
          _FieldLabel('Amount to swap'),
          const SizedBox(height: 8),
          AmountInput(
            controller: _amountCtrl,
            label: 'Amount',
            suffix: _fromAsset,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () =>
                  _amountCtrl.text = fromBal.toStringAsFixed(4),
              child: const Text('MAX',
                  style: TextStyle(
                      color: AppColors.accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ),
          ),

          // Swap preview
          if (amount > 0) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.divider),
              ),
              child: Column(children: [
                _R('Rate', '1 $_fromAsset ≈ 1 $_toAsset (stablecoins)'),
                const Divider(height: 18),
                _R('Swap fee (${wallet.swapFeePercent}%)',
                    '-${formatCrypto(fee)} $_fromAsset'),
                const Divider(height: 18),
                _R('You receive',
                    '${formatCrypto(received)} $_toAsset',
                    highlight: true),
              ]),
            ),
            const SizedBox(height: 16),
          ],

          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: _swap,
            icon: const Icon(Icons.currency_exchange_rounded),
            label: Text('Swap $_fromAsset → $_toAsset'),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.usdtColor),
          ),

          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(children: [
              Icon(Icons.info_outline,
                  color: AppColors.textSecondary, size: 16),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'USDT and USDC are stablecoins pegged to \$1. '
                  'Swap rate is 1:1 minus a small fee.',
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _AssetBox extends StatelessWidget {
  final String asset;
  final double balance;
  final Color color;
  const _AssetBox(
      {required this.asset, required this.balance, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Row(children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withAlpha(25),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(asset[0],
                style: TextStyle(
                    color: color,
                    fontSize: 15,
                    fontWeight: FontWeight.w800)),
          ),
        ),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(asset,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
          Text('Balance: ${formatCrypto(balance)}',
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 12)),
        ]),
      ]),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600));
}
