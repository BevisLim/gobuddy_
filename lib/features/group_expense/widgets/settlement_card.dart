import 'package:flutter/material.dart';
import '../../../core/utils/money_utils.dart';
import '../../../core/widgets/status_chip.dart';
import '../models/settlement.dart';

class SettlementCard extends StatelessWidget {
  const SettlementCard(
      {super.key,
      required this.settlement,
      required this.payerName,
      required this.payeeName});
  final Settlement settlement;
  final String payerName;
  final String payeeName;
  @override
  Widget build(BuildContext context) => Card(
      child: ListTile(
          title: Text('$payerName → $payeeName'),
          subtitle: Text(settlement.paymentMethod),
          trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(MoneyUtils.formatCurrency(settlement.amount)),
                StatusChip(label: settlement.status.name)
              ])));
}
