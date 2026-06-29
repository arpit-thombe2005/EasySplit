import 'package:intl/intl.dart';

/// Utility for formatting currency amounts consistently across the app.
class CurrencyFormatter {
  CurrencyFormatter._();

  /// Format an amount with the given currency code/symbol.
  static String format(double amount, {String currencyCode = 'INR'}) {
    final symbol = _symbolFor(currencyCode);
    final formatter = NumberFormat('#,##0.00', 'en_IN');
    return '$symbol${formatter.format(amount.abs())}';
  }

  /// Format a balance with sign prefix and color semantics (returns string).
  static String formatBalance(double amount, {String currencyCode = 'INR'}) {
    final formatted = format(amount.abs(), currencyCode: currencyCode);
    if (amount >= 0) return '+$formatted';
    return '-$formatted';
  }

  /// Format amount for display (compact: ₹1.2K, ₹1.5M)
  static String formatCompact(double amount, {String currencyCode = 'INR'}) {
    final symbol = _symbolFor(currencyCode);
    if (amount.abs() >= 1000000) {
      return '$symbol${(amount.abs() / 1000000).toStringAsFixed(1)}M';
    }
    if (amount.abs() >= 1000) {
      return '$symbol${(amount.abs() / 1000).toStringAsFixed(1)}K';
    }
    return format(amount, currencyCode: currencyCode);
  }

  static String _symbolFor(String code) {
    const symbols = {
      'INR': '₹',
      'USD': '\$',
      'EUR': '€',
      'GBP': '£',
      'JPY': '¥',
      'AUD': 'A\$',
      'CAD': 'C\$',
      'SGD': 'S\$',
      'AED': 'د.إ',
    };
    return symbols[code] ?? code;
  }
}

/// Extension on double for convenient currency formatting.
extension CurrencyExtension on double {
  String toCurrency({String currencyCode = 'INR'}) =>
      CurrencyFormatter.format(this, currencyCode: currencyCode);
}
