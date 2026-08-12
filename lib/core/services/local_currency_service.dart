import 'currency_service.dart';

class LocalCurrencyService implements CurrencyService {
  static const _myrValue = <String, double>{
    'MYR': 1,
    'USD': 4.65,
    'SGD': 3.45,
    'JPY': 0.031,
    'THB': 0.13,
    'EUR': 5.05,
  };
  @override
  Future<double> getExchangeRate(
      {required String fromCurrency, required String toCurrency}) async {
    final from = _myrValue[fromCurrency];
    final to = _myrValue[toCurrency];
    if (from == null || to == null) throw ArgumentError('Unsupported currency');
    return from / to;
  }
}
