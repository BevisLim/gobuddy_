import 'package:flutter/material.dart';

class SecondaryButton extends StatelessWidget {
  const SecondaryButton(
      {super.key, required this.label, required this.onPressed});
  final String label;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => SizedBox(
      width: double.infinity,
      child: OutlinedButton(
          onPressed: onPressed,
          child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(label))));
}
