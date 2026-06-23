// lib/services/api_enums.dart
//
// Enum-ы, отражающие справочники backend API (страны и валюты).
// Backend ожидает числовые id вместо строковых кодов, поэтому на фронтенде
// удобно держать enum с явным id и человекочитаемым названием.

/// Справочник стран. id соответствуют значениям, ожидаемым backend-ом.
/// Если backend пришлёт другой набор id — достаточно поправить только этот файл.
enum CountryId {
  ukraine(1, 'Ukraine'),
  unitedStates(2, 'United States'),
  unitedKingdom(3, 'United Kingdom'),
  germany(4, 'Germany'),
  poland(5, 'Poland'),
  other(99, 'Other');

  final int id;
  final String label;
  const CountryId(this.id, this.label);

  static CountryId fromId(int id) =>
      CountryId.values.firstWhere((c) => c.id == id, orElse: () => CountryId.other);
}

/// Справочник валют. id соответствуют значениям, ожидаемым backend-ом
/// при создании карты (`currencyId`) и в ответах (`currencyId` в карте).
enum CurrencyId {
  eur(1, 'EUR', '€'),
  usd(2, 'USD', '\$'),
  usdt(3, 'USDT', 'USDT'),
  usdc(4, 'USDC', 'USDC');

  final int id;
  final String code;
  final String symbol;
  const CurrencyId(this.id, this.code, this.symbol);

  static CurrencyId fromId(int id) =>
      CurrencyId.values.firstWhere((c) => c.id == id, orElse: () => CurrencyId.eur);

  static CurrencyId fromCode(String code) => CurrencyId.values.firstWhere(
        (c) => c.code.toUpperCase() == code.toUpperCase(),
        orElse: () => CurrencyId.eur,
      );
}

/// Направление конвертации для POST /api/transactions/convert.
/// walletToCard — списываем с криптокошелька, зачисляем на фиатную карту;
/// cardToFiat (наоборот) — списываем с карты, зачисляем на кошелёк.
enum ConversionDirection {
  walletToCard(0),
  cardToWallet(1);

  final int value;
  const ConversionDirection(this.value);
}
