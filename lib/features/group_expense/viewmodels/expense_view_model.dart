import 'package:flutter/foundation.dart';
import 'view_state.dart';

class ExpenseViewModel extends ChangeNotifier {
  ViewState state = ViewState.initial;
  String? errorMessage;
}
