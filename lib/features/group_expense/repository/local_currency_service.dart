import 'currency_service.dart';

class LocalCurrencyService implements CurrencyService {
  static const _myrPerUnit = <String, double>{
    'MYR': 1,
    'USD': 4.45,
    'SGD': 3.32,
    'JPY': 0.030,
    'THB': 0.13,
    'EUR': 4.85,
  };

  @override
  Future<double> getExchangeRate({
    required String fromCurrency,
    required String toCurrency,
  }) async {
    if (fromCurrency == toCurrency) return 1;
    final fromRate = _myrPerUnit[fromCurrency];
    final toRate = _myrPerUnit[toCurrency];
    if (fromRate == null || toRate == null) {
      throw ArgumentError('Unsupported currency conversion');
    }
    return fromRate / toRate;
  }
}
