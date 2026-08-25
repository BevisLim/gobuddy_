// This file is selected only for Flutter web by jitsi_call_embed.dart.
// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

class JitsiCallEmbed extends StatefulWidget {
  const JitsiCallEmbed({required this.roomUrl, super.key});

  final String roomUrl;

  @override
  State<JitsiCallEmbed> createState() => _JitsiCallEmbedState();
}

class _JitsiCallEmbedState extends State<JitsiCallEmbed> {
  late final String _viewType;

  @override
  void initState() {
    super.initState();
    _viewType = 'gobuddy-jitsi-${DateTime.now().microsecondsSinceEpoch}';
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (_) {
      return html.IFrameElement()
        ..src = widget.roomUrl
        ..allow = 'camera; microphone; autoplay; fullscreen; display-capture'
        ..style.border = '0'
        ..style.width = '100%'
        ..style.height = '100%';
    });
  }

  @override
  Widget build(BuildContext context) => HtmlElementView(viewType: _viewType);
}
