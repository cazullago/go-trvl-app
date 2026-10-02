import 'package:flutter/material.dart';
import 'live_video_provider.dart';

/// Video-call provider credentials.
///
/// The user adds their own Agora account credentials here (appId and a
/// generated token). These are intentionally blank: never invent or hardcode
/// credentials. When empty, [VideoCallService] shows a "coming soon"
/// message instead of attempting a call.
class VideoCallConfig {
  static const String provider = 'agora';
  static const String appId = '';
  static const String token = '';
}

/// One-to-one/group video calls for GoTRVL PH (e.g. calling a travel buddy).
///
/// Reuses [LiveVideoProvider] as the transport contract: once the user has
/// added their Agora credentials to [VideoCallConfig], plug a real provider
/// implementation into [provider] (see the hook point marked below). Until
/// then the bundled [StubLiveVideoProvider] prints to the log.
class VideoCallService {
  static final VideoCallService _i = VideoCallService._();
  factory VideoCallService() => _i;
  VideoCallService._();

  /// Swap this for the real Agora-backed provider once credentials exist.
  LiveVideoProvider provider = StubLiveVideoProvider();

  /// True when the user has added their provider credentials.
  bool get isConfigured => VideoCallConfig.appId.isNotEmpty;

  /// Starts a call with [peerName] on [channel].
  ///
  /// When no provider credentials are configured, shows a dialog saying
  /// video calls need a video provider (e.g. an Agora account) and that
  /// they are coming soon. Otherwise shows a short "connecting" placeholder
  /// and then a stub call screen marked as the provider hook point.
  Future<void> startCall(BuildContext context,
      {required String channel, required String peerName}) async {
    if (!isConfigured) {
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Video calls'),
          content: const Text(
              'Video calls need a video provider (e.g. an Agora account) — coming soon.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(c).pop(),
                child: const Text('OK')),
          ],
        ),
      );
      return;
    }

    // Placeholder "connecting" beat while the real SDK warms up.
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (c) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Connecting…'),
          ],
        ),
      ),
    );
    await provider.joinBroadcast(channel);
    if (!context.mounted) return;
    Navigator.of(context).pop(); // dismiss "connecting"

    // --- PROVIDER HOOK POINT ---
    // Replace this stub page with the real Agora video view once the SDK is
    // integrated; all call state flows through [provider].
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (c) => _StubCallScreen(
          peerName: peerName,
          onHangUp: () async {
            await provider.leave();
          },
        ),
      ),
    );
  }
}

/// Temporary call screen: stands in for the real video view until the
/// provider SDK is integrated.
class _StubCallScreen extends StatelessWidget {
  final String peerName;
  final Future<void> Function() onHangUp;

  const _StubCallScreen({required this.peerName, required this.onHangUp});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(peerName)),
      body: const Center(
        child: Text(
          'Video provider hook point\n(real video view renders here)',
          textAlign: TextAlign.center,
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await onHangUp();
          if (context.mounted) Navigator.of(context).pop();
        },
        child: const Icon(Icons.call_end),
      ),
    );
  }
}
