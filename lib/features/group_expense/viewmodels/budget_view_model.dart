import 'package:flutter/foundation.dart';
import 'view_state.dart';

class BudgetViewModel extends ChangeNotifier {
  ViewState state = ViewState.initial;
  String? errorMessage;
}
