import 'package:intl/intl.dart';

abstract final class AppDateUtils {
  static String formatDate(DateTime date) =>
      DateFormat('MMM d, yyyy').format(date);
  static String formatTripRange(DateTime start, DateTime end) {
    if (start.year == end.year && start.month == end.month) {
      return '${DateFormat('MMM d').format(start)}–${DateFormat('d, yyyy').format(end)}';
    }
    return '${formatDate(start)} – ${formatDate(end)}';
  }
}
