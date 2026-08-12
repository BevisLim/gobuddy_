import 'package:flutter/foundation.dart';
import 'view_state.dart';

class ExpenseDashboardViewModel extends ChangeNotifier {
  ViewState state = ViewState.initial;
  String? errorMessage;
  Future<void> loadDashboard(int tripId) async {}
  Future<void> refresh() async {}
}
