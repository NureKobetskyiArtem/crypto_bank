// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'providers/wallet_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/rates_provider.dart';
import 'utils/theme.dart';
import 'screens/home_screen.dart';
import 'screens/card_screen.dart';
import 'screens/history_screen.dart';
import 'screens/profile_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations(
      [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const CryptoBankApp());
}

class CryptoBankApp extends StatelessWidget {
  const CryptoBankApp({super.key});

  @override
  Widget build(BuildContext context) {
    // RatesProvider создаётся первым — WalletProvider зависит от него
    final ratesProvider = RatesProvider();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
        ChangeNotifierProvider<RatesProvider>(create: (_) => ratesProvider),
        ChangeNotifierProvider<WalletProvider>(
          create: (_) => WalletProvider(ratesProvider: ratesProvider),
        ),
      ],
      child: MaterialApp(
        title: 'CryptoBank Wallet',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: const RootShell(),
      ),
    );
  }
}

// ── Root Navigation Shell ─────────────────────────────────────────────────────

class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _currentIndex = 0;
  bool _wasAuthenticated = false;

  final _screens = const [
    HomeScreen(),
    CardScreen(),
    HistoryScreen(),
    ProfileScreen(),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.watch<AuthProvider>();
    // При первом успешном входе (или восстановлении сессии) подтягиваем
    // актуальные карты и балансы с backend (GET /api/cards).
    if (auth.isAuthenticated && !_wasAuthenticated) {
      _wasAuthenticated = true;
      final token = auth.accessToken;
      if (token != null && token.isNotEmpty) {
        final wallet = context.read<WalletProvider>();
        Future.microtask(() async {
          await wallet.syncCardsFromApi(
            token,
            holderNameFallback: auth.user?.displayName,
          );
          await wallet.syncWalletsFromApi(token);
          await wallet.syncTransactionsFromApi(token);
        });
      }
    } else if (!auth.isAuthenticated) {
      _wasAuthenticated = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: _BottomNav(
        currentIndex: _currentIndex,
        isAuthenticated: auth.isAuthenticated,
        onTap: (i) => setState(() => _currentIndex = i),
      ),
    );
  }
}

// ── Bottom Navigation ─────────────────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final bool isAuthenticated;
  final ValueChanged<int> onTap;

  const _BottomNav({
    required this.currentIndex,
    required this.isAuthenticated,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider, width: 1)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
                label: 'Wallet',
                selected: currentIndex == 0,
                onTap: () => onTap(0),
              ),
              _NavItem(
                icon: Icons.credit_card_outlined,
                activeIcon: Icons.credit_card_rounded,
                label: 'Card',
                selected: currentIndex == 1,
                onTap: () => onTap(1),
              ),
              _NavItem(
                icon: Icons.history_outlined,
                activeIcon: Icons.history_rounded,
                label: 'History',
                selected: currentIndex == 2,
                onTap: () => onTap(2),
              ),
              _NavItem(
                icon: isAuthenticated
                    ? Icons.person_outlined
                    : Icons.person_off_outlined,
                activeIcon: Icons.person_rounded,
                label: 'Profile',
                selected: currentIndex == 3,
                badge: !isAuthenticated,
                onTap: () => onTap(3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final bool badge;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accent.withAlpha(30)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  selected ? activeIcon : icon,
                  color: selected
                      ? AppColors.accent
                      : AppColors.textSecondary,
                  size: 24,
                ),
                if (badge)
                  Positioned(
                    right: -4,
                    top: -2,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(label,
                style: TextStyle(
                    color: selected
                        ? AppColors.accent
                        : AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: selected
                        ? FontWeight.w600
                        : FontWeight.w400)),
          ],
        ),
      ),
    );
  }
}
