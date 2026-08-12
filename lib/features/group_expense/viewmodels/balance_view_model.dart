import 'package:flutter/foundation.dart';
import 'view_state.dart';

class BalanceViewModel extends ChangeNotifier {
  ViewState state = ViewState.initial;
  String? errorMessage;
}
