import 'package:meta/meta.dart';

/// Supported currencies for checkout amounts.
enum Currency {
  /// Pakistani Rupee.
  pkr('PKR', minorUnitsPerMajor: 100);

  const Currency(this.code, {required this.minorUnitsPerMajor});

  /// ISO 4217 currency code.
  final String code;

  /// Number of minor units (e.g. paisa) in one major unit (e.g. rupee).
  final int minorUnitsPerMajor;
}

/// A validated monetary amount expressed in minor units.
///
/// Amounts are always stored as an integer number of minor units
/// (paisa for PKR) so that string formats such as `"1,000"`, `"Rs100"`
/// or `"100.00"` can never be interpreted differently by the gateway.
@immutable
class Money {
  /// Creates an amount from [minorUnits].
  ///
  /// Throws an [ArgumentError] if [minorUnits] is zero or negative.
  Money({required this.minorUnits, this.currency = Currency.pkr}) {
    if (minorUnits <= 0) {
      throw ArgumentError.value(
        minorUnits,
        'minorUnits',
        'Amount must be greater than zero',
      );
    }
  }

  /// Creates a PKR amount from a number of rupees.
  ///
  /// [rupees] may have at most two decimal places. Throws an
  /// [ArgumentError] for zero, negative, non-finite, or amounts with
  /// sub-paisa precision (e.g. `10.005`).
  factory Money.pkr(num rupees) {
    if (rupees is double && !rupees.isFinite) {
      throw ArgumentError.value(rupees, 'rupees', 'Amount must be finite');
    }
    final paisa = rupees * Currency.pkr.minorUnitsPerMajor;
    final rounded = paisa.round();
    if ((paisa - rounded).abs() > 1e-6) {
      throw ArgumentError.value(
        rupees,
        'rupees',
        'PKR amounts support at most two decimal places',
      );
    }
    return Money(minorUnits: rounded);
  }

  /// The amount in minor units (paisa for PKR).
  final int minorUnits;

  /// The currency of this amount.
  final Currency currency;

  /// The amount in major units, e.g. `2500.5` rupees.
  double get majorUnits => minorUnits / currency.minorUnitsPerMajor;

  /// The amount formatted with two decimal places, e.g. `"2500.00"`.
  ///
  /// This is the canonical string representation to send to a backend.
  String get formatted => majorUnits.toStringAsFixed(2);

  @override
  bool operator ==(Object other) =>
      other is Money &&
      other.minorUnits == minorUnits &&
      other.currency == currency;

  @override
  int get hashCode => Object.hash(minorUnits, currency);

  @override
  String toString() => '${currency.code} $formatted';
}
