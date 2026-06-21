// lib/screens/home_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/auth_provider.dart';
import '../providers/rates_provider.dart';
import '../providers/wallet_provider.dart';
import '../utils/formatters.dart';
import '../utils/theme.dart';
import '../widgets/widgets.dart';
import 'buy_screen.dart';
import 'convert_screen.dart';
import 'login_screen.dart';
import 'receive_screen.dart';
import 'register_screen.dart';
import 'send_screen.dart';
import 'transaction_detail_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    // Гость видит только публичный лендинг
    if (!auth.isAuthenticated) {
      return const _GuestLanding();
    }

    return const _WalletDashboard();
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Guest landing — никаких финансовых данных
// ═══════════════════════════════════════════════════════════════════════════════

class _GuestLanding extends StatelessWidget {
  const _GuestLanding();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 32, 28, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Logo
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.accent, Color(0xFF651FFF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Icon(Icons.account_balance_wallet_rounded,
                    color: Colors.white, size: 40),
              ),
              const SizedBox(height: 24),
              const Text('CryptoBank Wallet',
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 26,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              const Text(
                'Crypto & fiat in one place.\nSend, convert and pay — instantly.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 15, height: 1.6),
              ),

              const SizedBox(height: 36),

              // Feature cards
              ..._features.map((f) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _FeatureCard(icon: f.$1, title: f.$2, desc: f.$3),
                  )),

              const SizedBox(height: 32),

              // CTA
              ElevatedButton.icon(
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const LoginScreen())),
                icon: const Icon(Icons.login_rounded),
                label: const Text('Sign In'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const RegisterScreen())),
                icon: const Icon(Icons.person_add_outlined),
                label: const Text('Create Account'),
              ),

              const SizedBox(height: 32),

              // Locked info hint
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.divider),
                ),
                child: const Row(children: [
                  Icon(Icons.lock_outline,
                      color: AppColors.textSecondary, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Balances, cards, and transaction history '
                      'are only visible after sign-in.',
                      style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          height: 1.4),
                    ),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const _features = [
    (
      Icons.currency_bitcoin_rounded,
      'Crypto Wallet',
      'USDT & USDC — receive, send, swap'
    ),
    (
      Icons.swap_horiz_rounded,
      'Instant Conversion',
      'Crypto → EUR or USD with live rates'
    ),
    (
      Icons.credit_card_rounded,
      'Virtual Cards',
      'EUR and USD cards for bank transfers'
    ),
    (
      Icons.history_rounded,
      'Transaction History',
      'Full history with detailed receipts'
    ),
  ];
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;
  const _FeatureCard(
      {required this.icon, required this.title, required this.desc});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.accent.withAlpha(25),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.accent, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(desc,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12)),
            ],
          ),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Authenticated dashboard
// ═══════════════════════════════════════════════════════════════════════════════

class _WalletDashboard extends StatefulWidget {
  const _WalletDashboard();

  @override
  State<_WalletDashboard> createState() => _WalletDashboardState();
}

class _WalletDashboardState extends State<_WalletDashboard> {
  final _fiatPageCtrl = PageController();
  int _fiatPage = 0;

  @override
  void dispose() {
    _fiatPageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletProvider>();
    final auth = context.watch<AuthProvider>();
    final rates = context.watch<RatesProvider>();

    return Scaffold(
      body: SafeArea(
        child: LoadingOverlay(
          isLoading: wallet.isLoading,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      _Header(auth: auth),
                      const SizedBox(height: 20),

                      // Fiat balance swiper
                      _FiatBalanceSwiper(
                        pageCtrl: _fiatPageCtrl,
                        currentPage: _fiatPage,
                        eurBalance: wallet.eurBalance,
                        usdBalance: wallet.usdBalance,
                        onPageChanged: (i) => setState(() => _fiatPage = i),
                      ),

                      const SizedBox(height: 14),

                      // Crypto balances
                      Row(children: [
                        Expanded(
                          child: BalanceTile(
                            label: 'USDT (TRC-20)',
                            value:
                                '${formatCrypto(wallet.usdtBalance, decimals: 2)} USDT',
                            color: AppColors.usdtColor,
                            icon: Icons.monetization_on_outlined,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: BalanceTile(
                            label: 'USDC (Polygon)',
                            value:
                                '${formatCrypto(wallet.usdcBalance, decimals: 2)} USDC',
                            color: AppColors.usdcColor,
                            icon: Icons.toll_outlined,
                          ),
                        ),
                      ]),

                      const SizedBox(height: 22),

                      // Quick actions
                      const SectionHeader(title: 'Quick Actions'),
                      _QuickActions(),

                      const SizedBox(height: 22),

                      // Live rates
                      _RateBar(rates: rates),

                      const SizedBox(height: 22),
                      const SectionHeader(title: 'Recent Transactions'),
                    ],
                  ),
                ),
              ),

              // Transactions
              wallet.transactions.isEmpty
                  ? const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(
                          child: Column(children: [
                            Icon(Icons.inbox_outlined,
                                color: AppColors.textSecondary, size: 48),
                            SizedBox(height: 8),
                            Text('No transactions yet',
                                style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 15)),
                          ]),
                        ),
                      ),
                    )
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) {
                          final tx = wallet.transactions[i];
                          return _TxTile(tx: tx);
                        },
                        childCount: wallet.transactions.length,
                      ),
                    ),

              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final AuthProvider auth;
  const _Header({required this.auth});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            'Hello, ${auth.user!.displayName.split(' ').first}',
            style:
                const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const Text('Wallet',
              style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w800)),
        ]),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.success.withAlpha(30),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.success.withAlpha(80)),
          ),
          child: const Row(children: [
            Icon(Icons.circle, color: AppColors.success, size: 8),
            SizedBox(width: 6),
            Text('Live',
                style: TextStyle(
                    color: AppColors.success,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ]),
        ),
      ],
    );
  }
}

// ── Fiat balance swiper ───────────────────────────────────────────────────────

class _FiatBalanceSwiper extends StatelessWidget {
  final PageController pageCtrl;
  final int currentPage;
  final double eurBalance;
  final double usdBalance;
  final ValueChanged<int> onPageChanged;

  const _FiatBalanceSwiper({
    required this.pageCtrl,
    required this.currentPage,
    required this.eurBalance,
    required this.usdBalance,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      SizedBox(
        height: 150,
        child: PageView(
          controller: pageCtrl,
          onPageChanged: onPageChanged,
          children: [
            _FiatCard(
              label: 'EUR Balance',
              currency: 'EUR',
              value: formatFiat(eurBalance, 'EUR'),
              gradient: const [Color(0xFF3D5AFE), Color(0xFF651FFF)],
            ),
            _FiatCard(
              label: 'USD Balance',
              currency: 'USD',
              value: formatFiat(usdBalance, 'USD'),
              gradient: const [Color(0xFF1B5E20), Color(0xFF388E3C)],
            ),
          ],
        ),
      ),
      const SizedBox(height: 10),
      Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _SwiperDot(active: currentPage == 0),
              const SizedBox(width: 6),
              _SwiperDot(active: currentPage == 1),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              currentPage == 0 ? 'Swipe for USD →' : '← Swipe for EUR',
              style:
                  const TextStyle(color: AppColors.textSecondary, fontSize: 11),
            ),
          ),
        ],
      ),
    ]);
  }
}

class _SwiperDot extends StatelessWidget {
  final bool active;
  const _SwiperDot({required this.active});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: active ? 20 : 7,
      height: 7,
      decoration: BoxDecoration(
        color: active ? AppColors.accent : AppColors.divider,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

class _FiatCard extends StatelessWidget {
  final String label;
  final String currency;
  final String value;
  final List<Color> gradient;
  const _FiatCard({
    required this.label,
    required this.currency,
    required this.value,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: gradient.first.withAlpha(80),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w800,
                letterSpacing: -1)),
        const SizedBox(height: 4),
        Text(currency,
            style: const TextStyle(color: Colors.white60, fontSize: 13)),
      ]),
    );
  }
}

// ── Quick actions ─────────────────────────────────────────────────────────────

class _QuickActions extends StatelessWidget {
  void _push(BuildContext context, Widget screen) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        ActionButton(
          icon: Icons.call_received_outlined,
          label: 'Receive',
          color: AppColors.success,
          onTap: () => _push(context, const ReceiveScreen()),
        ),
        ActionButton(
          icon: Icons.send_outlined,
          label: 'Send',
          color: AppColors.warning,
          onTap: () => _push(context, const SendScreen()),
        ),
        ActionButton(
          icon: Icons.swap_horiz_outlined,
          label: 'Convert',
          color: AppColors.accent,
          onTap: () => _push(context, const ConvertScreen()),
        ),
        ActionButton(
          icon: Icons.add_card_outlined,
          label: 'Buy',
          color: AppColors.usdcColor,
          onTap: () => _push(context, const BuyScreen()),
        ),
      ],
    );
  }
}

// ── Rate bar ──────────────────────────────────────────────────────────────────

class _RateBar extends StatelessWidget {
  final RatesProvider rates;
  const _RateBar({required this.rates});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Live Rates',
                style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
            if (rates.isLoading)
              const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                      strokeWidth: 1.5, color: AppColors.accent))
            else
              GestureDetector(
                onTap: rates.fetchRates,
                child: const Icon(Icons.refresh_rounded,
                    color: AppColors.accent, size: 16),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _Rate('USDT→EUR', rates.usdtToEur.toStringAsFixed(4)),
            _Div(),
            _Rate('USDT→USD', rates.usdtToUsd.toStringAsFixed(4)),
            _Div(),
            _Rate('BTC', '\$${(rates.btcToUsd / 1000).toStringAsFixed(1)}k'),
          ],
        ),
      ]),
    );
  }
}

class _Div extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 28, color: AppColors.divider);
}

class _Rate extends StatelessWidget {
  final String label;
  final String value;
  const _Rate(this.label, this.value);

  @override
  Widget build(BuildContext context) => Column(children: [
        Text(value,
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(label,
            style:
                const TextStyle(color: AppColors.textSecondary, fontSize: 10)),
      ]);
}

// ── Transaction tile ──────────────────────────────────────────────────────────

class _TxTile extends StatelessWidget {
  final Transaction tx;
  const _TxTile({required this.tx});

  @override
  Widget build(BuildContext context) {
    final cfg = _cfg(tx);
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => TransactionDetailScreen(tx: tx)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: AppColors.cardBg,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: cfg.color.withAlpha(30),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(cfg.icon, color: cfg.color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tx.description,
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Text(formatDate(tx.date),
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 11)),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(cfg.amtStr,
                    style: TextStyle(
                        color: cfg.amtColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                    textAlign: TextAlign.end),
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.divider, size: 14),
              ],
            ),
          ]),
        ),
      ),
    );
  }

  _C _cfg(Transaction tx) {
    switch (tx.type) {
      case TransactionType.cryptoReceived:
        return _C(Icons.call_received_rounded, AppColors.success,
            '+${formatCrypto(tx.amount)} ${tx.currency}', AppColors.success);
      case TransactionType.cryptoSent:
        return _C(Icons.send_rounded, AppColors.warning,
            '-${formatCrypto(tx.amount)} ${tx.currency}', AppColors.warning);
      case TransactionType.cryptoToFiat:
        return _C(
            Icons.swap_horiz_rounded,
            AppColors.accent,
            '-${formatCrypto(tx.amount)} ${tx.currency}',
            AppColors.accentLight);
      case TransactionType.fiatToCrypto:
        return _C(Icons.add_card_rounded, AppColors.usdcColor,
            '-${formatFiat(tx.amount, tx.currency)}', AppColors.usdcColor);
      case TransactionType.cardPayment:
      case TransactionType.cardPaymentUsd:
        return _C(Icons.send_to_mobile_rounded, AppColors.error,
            '-${formatFiat(tx.amount, tx.currency)}', AppColors.error);
      case TransactionType.cryptoSwap:
        return _C(Icons.currency_exchange_rounded, AppColors.usdtColor,
            '${tx.currency}↔${tx.secondCurrency}', AppColors.usdtColor);
      case TransactionType.cardTopup:
        return _C(Icons.add_circle_outline, AppColors.success,
            '+${formatFiat(tx.amount, tx.currency)}', AppColors.success);
    }
  }
}

class _C {
  final IconData icon;
  final Color color;
  final String amtStr;
  final Color amtColor;
  const _C(this.icon, this.color, this.amtStr, this.amtColor);
}
