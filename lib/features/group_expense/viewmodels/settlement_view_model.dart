import 'package:flutter/foundation.dart';
import 'view_state.dart';

class SettlementViewModel extends ChangeNotifier {
  ViewState state = ViewState.initial;
  String? errorMessage;
}
