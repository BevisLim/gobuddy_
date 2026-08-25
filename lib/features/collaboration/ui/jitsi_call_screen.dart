import 'package:flutter/material.dart';

import 'package:flutter_mvvm_riverpod/features/collaboration/repository/jitsi_call_repository.dart';
import 'package:flutter_mvvm_riverpod/features/collaboration/ui/widgets/jitsi_call_embed.dart';

class JitsiCallScreen extends StatelessWidget {
  const JitsiCallScreen({
    required this.tripId,
    required this.callType,
    super.key,
  });

  final String tripId;
  final String callType;

  @override
  Widget build(BuildContext context) {
    final roomUrl = const JitsiCallRepository()
        .roomUri(tripId: tripId, callType: callType)
        .toString();
    return Scaffold(
      appBar: AppBar(
        title: Text(callType == 'video' ? 'Video call' : 'Voice call'),
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'Allow camera and microphone access in Chrome to join the call.',
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(child: JitsiCallEmbed(roomUrl: roomUrl)),
        ],
      ),
    );
  }
}
