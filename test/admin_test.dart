// Unit tests for the admin entrance pieces. These run with plain Dart and
// Flutter widgets only; Firebase is never touched here.
import 'package:flutter_test/flutter_test.dart';
import 'package:go_trvl/admin/triple_tap_detector.dart';
import 'package:go_trvl/admin/admin_auth_service.dart';

void main() {
  group('TripleTapDetector', () {
    test('three taps inside the window fires on the third tap', () {
      final detector = TripleTapDetector(windowMs: 1500);
      expect(detector.registerTap(0), isFalse);
      expect(detector.registerTap(500), isFalse);
      expect(detector.registerTap(1000), isTrue);
    });

    test('taps spread wider than the window never fire', () {
      final detector = TripleTapDetector(windowMs: 1500);
      expect(detector.registerTap(0), isFalse);
      expect(detector.registerTap(1000), isFalse);
      expect(detector.registerTap(2000), isFalse);
    });

    test('two taps do not fire', () {
      final detector = TripleTapDetector(windowMs: 1500);
      expect(detector.registerTap(0), isFalse);
      expect(detector.registerTap(700), isFalse);
    });

    test('detector resets after firing', () {
      final detector = TripleTapDetector(windowMs: 1500);
      detector.registerTap(0);
      detector.registerTap(500);
      expect(detector.registerTap(1000), isTrue);
      expect(detector.registerTap(1200), isFalse);
    });

    test('custom window is respected', () {
      final tight = TripleTapDetector(windowMs: 300);
      expect(tight.registerTap(0), isFalse);
      expect(tight.registerTap(150), isFalse);
      expect(tight.registerTap(500), isFalse);

      final wide = TripleTapDetector(windowMs: 5000);
      expect(wide.registerTap(0), isFalse);
      expect(wide.registerTap(2000), isFalse);
      expect(wide.registerTap(4000), isTrue);
    });
  });

  group('isAdminFromClaims', () {
    test('admin true is admin', () {
      expect(AdminAuthService.isAdminFromClaims({'admin': true}), isTrue);
    });

    test('admin false is not admin', () {
      expect(AdminAuthService.isAdminFromClaims({'admin': false}), isFalse);
    });

    test('empty claims are not admin', () {
      expect(AdminAuthService.isAdminFromClaims({}), isFalse);
    });

    test('null claims are not admin', () {
      expect(AdminAuthService.isAdminFromClaims(null), isFalse);
    });

    test('non-boolean admin claim is not admin', () {
      expect(AdminAuthService.isAdminFromClaims({'admin': 'yes'}), isFalse);
    });
  });
}
