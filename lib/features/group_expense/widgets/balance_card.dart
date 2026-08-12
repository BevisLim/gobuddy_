import 'package:flutter/material.dart';
import '../../../core/utils/money_utils.dart';
import '../../../core/widgets/traveller_avatar.dart';

class BalanceCard extends StatelessWidget {
  const BalanceCard(
      {super.key,
      required this.name,
      required this.initials,
      required this.balance});
  final String name;
  final String initials;
  final double balance;
  @override
  Widget build(BuildContext context) => Card(
      child: ListTile(
          leading: TravellerAvatar(initials: initials),
          title: Text(name),
          subtitle: Text(balance < 0
              ? 'Owes'
              : balance > 0
                  ? 'Gets back'
                  : 'Settled'),
          trailing: Text(MoneyUtils.formatCurrency(balance.abs()))));
}
