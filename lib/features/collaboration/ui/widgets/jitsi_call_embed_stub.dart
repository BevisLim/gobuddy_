import 'package:flutter/material.dart';

class JitsiCallEmbed extends StatelessWidget {
  const JitsiCallEmbed({required this.roomUrl, super.key});

  final String roomUrl;

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(24),
      child: Text(
        'In-app calls are available in the Flutter web version. '
        'Use the web app to join this Jitsi room.',
        textAlign: TextAlign.center,
      ),
    ),
  );
}
