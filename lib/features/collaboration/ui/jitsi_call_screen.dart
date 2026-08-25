import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:flutter_mvvm_riverpod/features/collaboration/repository/jitsi_call_repository.dart';
import 'package:flutter_mvvm_riverpod/features/collaboration/repository/native_jitsi_call.dart';
import 'package:flutter_mvvm_riverpod/features/collaboration/ui/widgets/jitsi_call_embed.dart';

class JitsiCallScreen extends StatefulWidget {
  const JitsiCallScreen({
    required this.tripId,
    required this.callType,
    super.key,
  });

  final String tripId;
  final String callType;

  @override
  State<JitsiCallScreen> createState() => _JitsiCallScreenState();
}

class _JitsiCallScreenState extends State<JitsiCallScreen> {
  bool _joiningNativeCall = false;
  String? _nativeError;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) _joinNativeCall();
  }

  Future<void> _joinNativeCall() async {
    setState(() => _joiningNativeCall = true);
    try {
      final joined = await const NativeJitsiCall().join(
        room: const JitsiCallRepository().roomNameForTrip(widget.tripId),
        callType: widget.callType,
      );
      if (mounted && !joined) {
        setState(
          () => _nativeError = 'Calls are supported on Android and iPhone.',
        );
      }
    } catch (error) {
      if (mounted) setState(() => _nativeError = '$error');
    } finally {
      if (mounted) setState(() => _joiningNativeCall = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final roomUrl = const JitsiCallRepository()
        .roomUri(tripId: widget.tripId, callType: widget.callType)
        .toString();
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.callType == 'video' ? 'Video call' : 'Voice call'),
      ),
      body: kIsWeb
          ? Column(
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
            )
          : Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: _joiningNativeCall
                    ? const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Opening secure in-app call...'),
                        ],
                      )
                    : Text(
                        _nativeError ?? 'The call window is open.',
                        textAlign: TextAlign.center,
                      ),
              ),
            ),
    );
  }
}
