/// Contract for live video transport in GoTRVL PH.
///
/// The metadata/chat layer lives in LiveService; this interface is the
/// integration point for an actual real-time video SDK.
///
/// NOTE: one-to-one / group video calls go through VideoCallService
/// (lib/services/video_call_service.dart), which holds a provider of this
/// type. Broadcasts keep using LiveService + a provider wired here.
abstract class LiveVideoProvider {
  Future<void> startBroadcast(String streamId);
  Future<void> joinBroadcast(String streamId);
  Future<void> leave();
}

/// No-op provider used until a real video SDK is integrated.
///
/// TODO: Integration point: plug in Agora / Mux / 100ms SDK here.
/// No real video SDK is bundled.
class StubLiveVideoProvider implements LiveVideoProvider {
  @override
  Future<void> startBroadcast(String streamId) async {
    // TODO: start the real broadcast via the chosen video SDK.
    print('[LiveVideo] stub startBroadcast($streamId): no SDK bundled.');
  }

  @override
  Future<void> joinBroadcast(String streamId) async {
    // TODO: join the real broadcast via the chosen video SDK.
    print('[LiveVideo] stub joinBroadcast($streamId): no SDK bundled.');
  }

  @override
  Future<void> leave() async {
    // TODO: leave and dispose the real broadcast via the chosen video SDK.
    print('[LiveVideo] stub leave(): no SDK bundled.');
  }
}
