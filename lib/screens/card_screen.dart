// lib/screens/card_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/wallet_provider.dart';
import '../providers/auth_provider.dart';
import '../utils/theme.dart';
import '../utils/formatters.dart';
import '../widgets/widgets.dart';
import '../models/models.dart';
import 'login_screen.dart';
import 'transaction_detail_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// CardScreen — главный экран с PageView (EUR / USD карты)
// ═══════════════════════════════════════════════════════════════════════════════

class CardScreen extends StatefulWidget {
  const CardScreen({super.key});

  @override
  State<CardScreen> createState() => _CardScreenState();
}

class _CardScreenState extends State<CardScreen> {
  final _pageCtrl = PageController();
  int _currentPage = 0; // 0 = EUR, 1 = USD

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletProvider>();
    final auth = context.watch<AuthProvider>();

    // Гость не должен видеть карты и балансы
    if (!auth.isAuthenticated) {
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
                    child: const Icon(Icons.credit_card_off_outlined,
                        color: AppColors.textSecondary, size: 34),
                  ),
                  const SizedBox(height: 20),
                  const Text('Cards are private',
                      style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  const Text(
                    'Sign in to view and manage your virtual cards.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                        height: 1.5),
                  ),
                  const SizedBox(height: 28),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.push(context,
                        MaterialPageRoute(
                            builder: (_) => const LoginScreen())),
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

    return Scaffold(
      body: SafeArea(
        child: LoadingOverlay(
          isLoading: wallet.isLoading,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Title ──────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Virtual',
                        style: TextStyle(
                            color: AppColors.textSecondary, fontSize: 13)),
                    const Text('Cards',
                        style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 24,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    // Page dots
                    Row(children: [
                      _Dot(active: _currentPage == 0),
                      const SizedBox(width: 6),
                      _Dot(active: _currentPage == 1),
                      const SizedBox(width: 10),
                      Text(
                        _currentPage == 0 ? 'EUR Card' : 'USD Card',
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ]),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── Swipeable pages ────────────────────────────────────────────
              Expanded(
                child: PageView(
                  controller: _pageCtrl,
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  children: [
                    _CardPage(
                      currency: 'EUR',
                      card: wallet.eurCard,
                      balance: wallet.eurBalance,
                      transactions: wallet.eurCardTransactions,
                      wallet: wallet,
                      auth: auth,
                    ),
                    _CardPage(
                      currency: 'USD',
                      card: wallet.usdCard,
                      balance: wallet.usdBalance,
                      transactions: wallet.usdCardTransactions,
                      wallet: wallet,
                      auth: auth,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  final bool active;
  const _Dot({required this.active});

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

// ═══════════════════════════════════════════════════════════════════════════════
// _CardPage — одна страница (EUR или USD)
// ═══════════════════════════════════════════════════════════════════════════════

class _CardPage extends StatefulWidget {
  final String currency;
  final VirtualCard? card;
  final double balance;
  final List<Transaction> transactions;
  final WalletProvider wallet;
  final AuthProvider auth;

  const _CardPage({
    required this.currency,
    required this.card,
    required this.balance,
    required this.transactions,
    required this.wallet,
    required this.auth,
  });

  @override
  State<_CardPage> createState() => _CardPageState();
}

class _CardPageState extends State<_CardPage> {
  bool _cvvVisible = false;
  bool _numberVisible = false;
  final _nameCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.card != null ? _buildCardView() : _buildIssueView();
  }

  // ── Has card ───────────────────────────────────────────────────────────────

  Widget _buildCardView() {
    final card = widget.card!;
    final txs = widget.transactions;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card visual
          _CardVisual(
            card: card,
            cvvVisible: _cvvVisible,
            numberVisible: _numberVisible,
          ),

          const SizedBox(height: 12),

          // Reveal controls
          Row(children: [
            Expanded(
              child: _RevealBtn(
                label: _numberVisible ? 'Hide No.' : 'Show No.',
                icon: _numberVisible
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                onTap: () =>
                    setState(() => _numberVisible = !_numberVisible),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _RevealBtn(
                label: _cvvVisible ? 'Hide CVV' : 'Show CVV',
                icon: _cvvVisible
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                onTap: () =>
                    setState(() => _cvvVisible = !_cvvVisible),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(
                    text: card.number.replaceAll(' ', '')));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Card number copied'),
                    duration: Duration(seconds: 2)));
              },
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size(44, 44),
                  padding: EdgeInsets.zero),
              child: const Icon(Icons.copy_outlined, size: 18),
            ),
          ]),

          const SizedBox(height: 16),

          // Balance
          _BalanceBar(
              balance: widget.balance, currency: widget.currency),

          const SizedBox(height: 20),

          // Action buttons
          const Text('Actions',
              style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5)),
          const SizedBox(height: 10),

          _ActionCard(
            icon: Icons.send_rounded,
            iconColor: AppColors.success,
            title: 'Send Transfer',
            subtitle: 'Transfer to card number or IBAN',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SendTransferScreen(
                  cardCurrency: widget.currency,
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),

          _ActionCard(
            icon: Icons.credit_card_rounded,
            iconColor: AppColors.accent,
            title: 'Card Details',
            subtitle: 'View full number, CVV and expiry',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CardDetailsScreen(card: card),
              ),
            ),
          ),

          // Recent transactions
          if (txs.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text('Recent Transfers',
                style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5)),
            const SizedBox(height: 10),
            ...txs.take(5).map((tx) => _TxTile(
                  tx: tx,
                  currency: widget.currency,
                )),
          ],
        ],
      ),
    );
  }

  // ── No card yet ────────────────────────────────────────────────────────────

  Widget _buildIssueView() {
    final color = widget.currency == 'EUR'
        ? AppColors.accent
        : AppColors.usdtColor;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 16),
          Icon(Icons.credit_card_outlined, color: color, size: 64),
          const SizedBox(height: 16),
          Text('${widget.currency} Virtual Card',
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            'Issue a virtual Visa card linked to your\n'
            '${widget.currency} balance.',
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 28),
          ...[
            ('Send bank transfers', Icons.swap_horiz_rounded),
            ('Linked to ${widget.currency} balance',
                Icons.account_balance_wallet_outlined),
            ('Instant issuance, no fee', Icons.flash_on_outlined),
          ].map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(children: [
                  Icon(item.$2, color: AppColors.success, size: 20),
                  const SizedBox(width: 12),
                  Text(item.$1,
                      style: const TextStyle(
                          color: AppColors.textPrimary, fontSize: 14)),
                ]),
              )),
          const SizedBox(height: 24),
          TextField(
            controller: _nameCtrl,
            textCapitalization: TextCapitalization.words,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(
              labelText: 'Cardholder Name',
              hintText: 'JOHN DOE',
              prefixIcon: Icon(Icons.person_outline,
                  color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _issueCard(context),
            icon: const Icon(Icons.add_card_rounded),
            label: Text('Issue ${widget.currency} Card'),
            style: ElevatedButton.styleFrom(backgroundColor: color),
          ),
        ],
      ),
    );
  }

  Future<void> _issueCard(BuildContext context) async {
    if (!widget.auth.isAuthenticated) {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => const LoginScreen()));
      return;
    }
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Enter cardholder name'),
          backgroundColor: AppColors.error));
      return;
    }
    final err = await widget.wallet.issueCard(
      _nameCtrl.text,
      widget.currency,
      accessToken: widget.auth.accessToken,
    );
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(err), backgroundColor: AppColors.error));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${widget.currency} card issued!'),
        backgroundColor: AppColors.success));
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SendTransferScreen
// ═══════════════════════════════════════════════════════════════════════════════

class SendTransferScreen extends StatefulWidget {
  final String cardCurrency;
  const SendTransferScreen({super.key, required this.cardCurrency});

  @override
  State<SendTransferScreen> createState() => _SendTransferScreenState();
}

class _SendTransferScreenState extends State<SendTransferScreen> {
  final _recipientCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  String _transferType = 'CARD';

  @override
  void initState() {
    super.initState();
    _amountCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _recipientCtrl.dispose();
    _nameCtrl.dispose();
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wallet = context.watch<WalletProvider>();
    final balance = widget.cardCurrency == 'USD'
        ? wallet.usdBalance
        : wallet.eurBalance;

    return Scaffold(
      appBar: AppBar(
        title: Text('Send (${widget.cardCurrency})'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: LoadingOverlay(
        isLoading: wallet.isLoading,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Balance bar
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${widget.cardCurrency} Available',
                        style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13)),
                    Text(formatFiat(balance, widget.cardCurrency),
                        style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              _FL('Transfer Type'),
              const SizedBox(height: 8),
              AssetSelector(
                selected: _transferType,
                onChanged: (v) => setState(() {
                  _transferType = v;
                  _recipientCtrl.clear();
                }),
                assets: const ['CARD', 'IBAN'],
              ),

              const SizedBox(height: 18),

              _FL(_transferType == 'CARD'
                  ? 'Recipient Card Number'
                  : 'IBAN'),
              const SizedBox(height: 8),
              TextField(
                controller: _recipientCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontFamily: 'monospace',
                    letterSpacing: 1.5),
                inputFormatters: _transferType == 'CARD'
                    ? [
                        FilteringTextInputFormatter.digitsOnly,
                        _CardFmt(),
                      ]
                    : [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'[A-Za-z0-9]')),
                        _IBANFmt(),
                      ],
                decoration: InputDecoration(
                  hintText: _transferType == 'CARD'
                      ? '0000 0000 0000 0000'
                      : 'DE89 3704 0044 0532 0130 00',
                  prefixIcon: Icon(
                    _transferType == 'CARD'
                        ? Icons.credit_card_outlined
                        : Icons.account_balance_outlined,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),

              const SizedBox(height: 16),
              _FL('Recipient Name'),
              const SizedBox(height: 8),
              TextField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'John Doe',
                  prefixIcon: Icon(Icons.person_outline,
                      color: AppColors.textSecondary),
                ),
              ),

              const SizedBox(height: 16),
              _FL('Amount'),
              const SizedBox(height: 8),
              AmountInput(
                controller: _amountCtrl,
                label: 'Amount',
                suffix: widget.cardCurrency,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                children: [10.0, 25.0, 50.0, 100.0, 250.0].map((v) {
                  final sym = widget.cardCurrency == 'EUR' ? '€' : '\$';
                  return ActionChip(
                    label: Text('$sym${v.toInt()}',
                        style: const TextStyle(fontSize: 12)),
                    onPressed: () =>
                        _amountCtrl.text = v.toStringAsFixed(2),
                    backgroundColor: AppColors.surface,
                    labelStyle: const TextStyle(
                        color: AppColors.textPrimary),
                    side: const BorderSide(color: AppColors.divider),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    visualDensity: VisualDensity.compact,
                  );
                }).toList(),
              ),

              const SizedBox(height: 16),
              _FL('Note (optional)'),
              const SizedBox(height: 8),
              TextField(
                controller: _noteCtrl,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'E.g. Rent for October',
                  prefixIcon: Icon(Icons.notes_outlined,
                      color: AppColors.textSecondary),
                ),
              ),

              const SizedBox(height: 24),

              if ((_amountCtrl.text.isNotEmpty) &&
                  (double.tryParse(_amountCtrl.text) ?? 0) > 0)
                _TransferPreview(
                  amount: double.parse(_amountCtrl.text),
                  balance: balance,
                  currency: widget.cardCurrency,
                ),

              const SizedBox(height: 20),

              ElevatedButton.icon(
                onPressed: () => _send(context, wallet),
                icon: const Icon(Icons.send_rounded),
                label: const Text('Send Transfer'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _send(BuildContext context, WalletProvider wallet) async {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => const LoginScreen()));
      return;
    }

    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) { _err(context, 'Enter a valid amount'); return; }

    final rawRecipient = _recipientCtrl.text.replaceAll(' ', '');
    if (_transferType == 'CARD' && rawRecipient.length != 16) {
      _err(context, 'Enter a valid 16-digit card number'); return;
    }
    if (_transferType == 'IBAN' && rawRecipient.length < 15) {
      _err(context, 'Enter a valid IBAN'); return;
    }
    if (_nameCtrl.text.trim().isEmpty) {
      _err(context, 'Enter recipient name'); return;
    }

    final bal = widget.cardCurrency == 'USD'
        ? wallet.usdBalance
        : wallet.eurBalance;
    if (amount > bal) {
      _err(context, 'Insufficient ${widget.cardCurrency} balance'); return;
    }

    // Confirm dialog
    final sym = widget.cardCurrency == 'EUR' ? '€' : '\$';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirm Transfer',
            style: TextStyle(color: AppColors.textPrimary)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          _CR('Amount', '$sym${amount.toStringAsFixed(2)}', highlight: true),
          _CR('To', _nameCtrl.text.trim()),
          _CR(_transferType, _maskDisplay(_recipientCtrl.text)),
          if (_noteCtrl.text.trim().isNotEmpty)
            _CR('Note', _noteCtrl.text.trim()),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.textSecondary))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                minimumSize: const Size(88, 38)),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirm != true || !context.mounted) return;

    final err = await wallet.cardPayment(
      amount: amount,
      cardCurrency: widget.cardCurrency,
      recipientCard: _recipientCtrl.text,
      recipientName: _nameCtrl.text,
      note: _noteCtrl.text,
    );
    if (!context.mounted) return;

    if (err != null) {
      _err(context, err);
    } else {
      _amountCtrl.clear();
      _recipientCtrl.clear();
      _nameCtrl.clear();
      _noteCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'Transfer of ${formatFiat(amount, widget.cardCurrency)} sent!'),
        backgroundColor: AppColors.success,
      ));
      Navigator.pop(context);
    }
  }

  void _err(BuildContext ctx, String msg) => ScaffoldMessenger.of(ctx)
      .showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: AppColors.error));

  String _maskDisplay(String input) {
    final clean = input.replaceAll(' ', '');
    if (clean.length <= 8) return input;
    return '${clean.substring(0, 4)} **** **** ${clean.substring(clean.length - 4)}';
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CardDetailsScreen
// ═══════════════════════════════════════════════════════════════════════════════

class CardDetailsScreen extends StatefulWidget {
  final VirtualCard card;
  const CardDetailsScreen({super.key, required this.card});

  @override
  State<CardDetailsScreen> createState() => _CardDetailsScreenState();
}

class _CardDetailsScreenState extends State<CardDetailsScreen> {
  bool _cvvVisible = false;
  bool _numberVisible = false;

  @override
  Widget build(BuildContext context) {
    final card = widget.card;
    return Scaffold(
      appBar: AppBar(
        title: Text('${card.currency} Card Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CardVisual(
                card: card,
                cvvVisible: _cvvVisible,
                numberVisible: _numberVisible),

            const SizedBox(height: 14),

            Row(children: [
              Expanded(
                child: _RevealBtn(
                  label: _numberVisible ? 'Hide Number' : 'Show Number',
                  icon: _numberVisible
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  onTap: () =>
                      setState(() => _numberVisible = !_numberVisible),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _RevealBtn(
                  label: _cvvVisible ? 'Hide CVV' : 'Show CVV',
                  icon: _cvvVisible
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  onTap: () =>
                      setState(() => _cvvVisible = !_cvvVisible),
                ),
              ),
            ]),

            const SizedBox(height: 24),

            const _SL('Details'),
            const SizedBox(height: 10),

            _DR(label: 'Cardholder', value: card.holderName,
                icon: Icons.person_outline),
            _DR(
              label: 'Card Number',
              value: _numberVisible ? card.number : card.maskedNumber,
              icon: Icons.credit_card_outlined,
              copyValue: card.number.replaceAll(' ', ''),
            ),
            _DR(label: 'Expiry', value: card.expiry,
                icon: Icons.calendar_month_outlined),
            _DR(
              label: 'CVV',
              value: _cvvVisible ? card.cvv : '•••',
              icon: Icons.lock_outline,
              copyValue: _cvvVisible ? card.cvv : null,
            ),
            _DR(label: 'Currency', value: card.currency,
                icon: Icons.euro_outlined),
            _DR(label: 'Type', value: 'Visa Virtual',
                icon: Icons.payment_outlined),
            _DR(
              label: 'Status',
              value: card.isActive ? 'Active' : 'Inactive',
              icon: Icons.circle,
              valueColor:
                  card.isActive ? AppColors.success : AppColors.error,
            ),

            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.warning.withAlpha(18),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.warning.withAlpha(60)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.shield_outlined,
                      color: AppColors.warning, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Keep your CVV and full card number private. '
                      'CryptoBank will never ask for these details '
                      'via email or phone.',
                      style: TextStyle(
                          color: AppColors.warning,
                          fontSize: 12,
                          height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Shared small widgets
// ═══════════════════════════════════════════════════════════════════════════════

class _BalanceBar extends StatelessWidget {
  final double balance;
  final String currency;
  const _BalanceBar({required this.balance, required this.currency});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Available Balance',
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 4),
            Text(formatFiat(balance, currency),
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w800)),
          ]),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.success.withAlpha(25),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.success.withAlpha(60)),
            ),
            child: Text(currency,
                style: const TextStyle(
                    color: AppColors.success,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.cardBg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: iconColor.withAlpha(25),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 12),
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
                  Text(subtitle,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textSecondary, size: 20),
          ]),
        ),
      ),
    );
  }
}

class _TxTile extends StatelessWidget {
  final Transaction tx;
  final String currency;
  const _TxTile({required this.tx, required this.currency});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => TransactionDetailScreen(tx: tx)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.error.withAlpha(25),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.send_rounded,
                color: AppColors.error, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tx.recipientName ?? tx.description,
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
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('-${formatFiat(tx.amount, currency)}',
                style: const TextStyle(
                    color: AppColors.error,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.divider, size: 16),
          ]),
        ]),
      ),
    );
  }
}

class _RevealBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _RevealBtn({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 15),
        label: Text(label, style: const TextStyle(fontSize: 12)),
        style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 10)),
      );
}

class _TransferPreview extends StatelessWidget {
  final double amount;
  final double balance;
  final String currency;
  const _TransferPreview(
      {required this.amount, required this.balance, required this.currency});

  @override
  Widget build(BuildContext context) {
    final remaining = balance - amount;
    final bad = remaining < 0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: bad ? AppColors.error.withAlpha(80) : AppColors.divider),
      ),
      child: Column(children: [
        _PRow('Transfer', formatFiat(amount, currency)),
        _PRow('Balance', formatFiat(balance, currency)),
        const Divider(height: 14),
        _PRow('After transfer',
            formatFiat(bad ? 0 : remaining, currency),
            color: bad ? AppColors.error : AppColors.success),
        if (bad)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(children: [
              const Icon(Icons.warning_rounded,
                  color: AppColors.error, size: 14),
              const SizedBox(width: 4),
              Text('Need ${formatFiat(amount - balance, currency)} more',
                  style: const TextStyle(
                      color: AppColors.error, fontSize: 12)),
            ]),
          ),
      ]),
    );
  }
}

class _PRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _PRow(this.label, this.value, {this.color});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13)),
            Text(value,
                style: TextStyle(
                    color: color ?? AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      );
}

class _CR extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;
  const _CR(this.label, this.value, {this.highlight = false});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 64,
            child: Text('$label:',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    color: highlight
                        ? AppColors.success
                        : AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ),
        ]),
      );
}

// ── Section label ─────────────────────────────────────────────────────────────
class _SL extends StatelessWidget {
  final String text;
  const _SL(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5));
}

// ── Field label ───────────────────────────────────────────────────────────────
class _FL extends StatelessWidget {
  final String text;
  const _FL(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600));
}

// ── Detail row ────────────────────────────────────────────────────────────────
class _DR extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final String? copyValue;
  final Color? valueColor;

  const _DR({
    required this.label,
    required this.value,
    required this.icon,
    this.copyValue,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, color: AppColors.textSecondary, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 11)),
            const SizedBox(height: 2),
            Text(value,
                style: TextStyle(
                    color: valueColor ?? AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'monospace')),
          ]),
        ),
        if (copyValue != null)
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: copyValue!));
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('$label copied'),
                  duration: const Duration(seconds: 1)));
            },
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.copy_outlined,
                  color: AppColors.textSecondary, size: 17),
            ),
          ),
      ]),
    );
  }
}

// ── Card visual ───────────────────────────────────────────────────────────────
class _CardVisual extends StatelessWidget {
  final VirtualCard card;
  final bool cvvVisible;
  final bool numberVisible;
  const _CardVisual(
      {required this.card,
      required this.cvvVisible,
      required this.numberVisible});

  @override
  Widget build(BuildContext context) {
    final isUsd = card.currency == 'USD';
    final gradColors = isUsd
        ? const [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF388E3C)]
        : const [Color(0xFF1A237E), Color(0xFF283593), Color(0xFF3949AB)];

    return Container(
      width: double.infinity,
      height: 190,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(100),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(children: [
        Positioned(
          top: -30, right: -30,
          child: Container(
            width: 160, height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withAlpha(15),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('CryptoBank',
                      style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1)),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(30),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(card.currency,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(30),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('VISA',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              fontStyle: FontStyle.italic)),
                    ),
                  ]),
                ],
              ),
              const Spacer(),
              Text(
                numberVisible ? card.number : card.maskedNumber,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2,
                    fontFamily: 'monospace'),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('CARDHOLDER',
                        style: TextStyle(
                            color: Colors.white54, fontSize: 9, letterSpacing: 1)),
                    Text(card.holderName,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                  ]),
                  Row(children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('EXPIRES',
                          style: TextStyle(
                              color: Colors.white54, fontSize: 9, letterSpacing: 1)),
                      Text(card.expiry,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                    ]),
                    const SizedBox(width: 16),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('CVV',
                          style: TextStyle(
                              color: Colors.white54, fontSize: 9, letterSpacing: 1)),
                      Text(cvvVisible ? card.cvv : '•••',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                    ]),
                  ]),
                ],
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

// ── Input formatters ──────────────────────────────────────────────────────────

class _CardFmt extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue old, TextEditingValue next) {
    final digits = next.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 16) return old;
    final buf = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && i % 4 == 0) buf.write(' ');
      buf.write(digits[i]);
    }
    final s = buf.toString();
    return TextEditingValue(
        text: s, selection: TextSelection.collapsed(offset: s.length));
  }
}

class _IBANFmt extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue old, TextEditingValue next) {
    final clean =
        next.text.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (clean.length > 34) return old;
    final buf = StringBuffer();
    for (int i = 0; i < clean.length; i++) {
      if (i > 0 && i % 4 == 0) buf.write(' ');
      buf.write(clean[i]);
    }
    final s = buf.toString();
    return TextEditingValue(
        text: s, selection: TextSelection.collapsed(offset: s.length));
  }
}
