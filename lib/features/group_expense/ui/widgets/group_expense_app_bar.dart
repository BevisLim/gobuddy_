import 'package:flutter/material.dart';

class GroupExpenseAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const GroupExpenseAppBar({
    super.key,
    required this.title,
    this.actions,
  });

  final String title;
  final List<Widget>? actions;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) => AppBar(
        backgroundColor: const Color(0xFF281958),
        foregroundColor: Colors.white,
        title: Text(title),
        actions: actions,
      );
}
