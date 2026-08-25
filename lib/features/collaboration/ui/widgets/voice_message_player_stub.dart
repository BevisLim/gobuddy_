import 'package:flutter/material.dart';

class VoiceMessagePlayer extends StatelessWidget {
  const VoiceMessagePlayer({required this.url, super.key});

  final String url;

  @override
  Widget build(BuildContext context) => const Text('Voice message attached');
}
