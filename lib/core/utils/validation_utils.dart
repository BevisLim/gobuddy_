abstract final class ValidationUtils {
  static String? requiredText(String? value, {String field = 'This field'}) =>
      value == null || value.trim().isEmpty ? '$field is required' : null;
  static String? positiveAmount(String? value) {
    final amount = double.tryParse(value?.trim() ?? '');
    return amount == null || amount <= 0
        ? 'Enter an amount greater than zero'
        : null;
  }
}
