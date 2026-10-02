// Triple-tap detector: pure Dart, no Flutter imports.
//
// The triple tap only REVEALS the admin login screen. It never bypasses
// authentication. Admin access is decided by the Firebase Auth custom claim
// (admin: true), which is set off device via the Admin SDK. Obscurity is not
// security: anyone who reaches the login screen still has to sign in with a
// real admin credential and pass the custom claim check.
class TripleTapDetector {
  final int windowMs;
  final List<int> _times = [];

  TripleTapDetector({this.windowMs = 1500});

  /// Registers a tap at [nowMs] (milliseconds). Returns true when three taps
  /// landed inside the rolling [windowMs] window, and resets the detector.
  bool registerTap(int nowMs) {
    _times.add(nowMs);
    _times.removeWhere((t) => nowMs - t > windowMs);
    if (_times.length >= 3) {
      _times.clear();
      return true;
    }
    return false;
  }

  /// Clears any taps seen so far.
  void reset() => _times.clear();
}
