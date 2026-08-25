// This implementation is selected only for Flutter web.
// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

class VoiceMessagePlayer extends StatefulWidget {
  const VoiceMessagePlayer({required this.url, super.key});

  final String url;

  @override
  State<VoiceMessagePlayer> createState() => _VoiceMessagePlayerState();
}

class _VoiceMessagePlayerState extends State<VoiceMessagePlayer> {
  late final String _viewType;

  @override
  void initState() {
    super.initState();
    _viewType = 'gobuddy-voice-${DateTime.now().microsecondsSinceEpoch}';
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (_) {
      return html.AudioElement()
        ..src = widget.url
        ..controls = true
        ..style.width = '220px';
    });
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 44,
    width: 220,
    child: HtmlElementView(viewType: _viewType),
  );
}
