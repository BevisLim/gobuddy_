abstract interface class CurrencyService {
  Future<double> getExchangeRate({
    required String fromCurrency,
    required String toCurrency,
  });
}
