import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Central permission helper for camera, photos, microphone, location and
/// notifications.
///
/// Flow per permission: granted (or limited, on iOS) → true; denied →
/// show a rationale dialog carrying the caller's [reason] with
/// Continue/Cancel, then request; permanentlyDenied or restricted → show a
/// dialog with "Open Settings" that deep-links into the app settings page.
/// Never throws; returns false whenever the permission is not granted.
class PermissionService {
  static final PermissionService _i = PermissionService._();
  factory PermissionService() => _i;
  PermissionService._();

  Future<bool> ensureCamera(BuildContext context, String reason) =>
      _ensure(context, Permission.camera, 'Camera', reason);

  Future<bool> ensurePhotos(BuildContext context, String reason) =>
      _ensure(context, Permission.photos, 'Photos', reason);

  Future<bool> ensureMicrophone(BuildContext context, String reason) =>
      _ensure(context, Permission.microphone, 'Microphone', reason);

  Future<bool> ensureLocation(BuildContext context, String reason) =>
      _ensure(context, Permission.locationWhenInUse, 'Location', reason);

  Future<bool> ensureNotifications(BuildContext context, String reason) =>
      _ensure(context, Permission.notification, 'Notifications', reason);

  Future<bool> _ensure(
      BuildContext context, Permission permission, String label, String reason) async {
    try {
      final status = await permission.status;
      if (status == PermissionStatus.granted ||
          status == PermissionStatus.limited) {
        return true;
      }
      if (status == PermissionStatus.permanentlyDenied ||
          status == PermissionStatus.restricted) {
        final opened = await _settingsDialog(context, label);
        if (opened == true) await openAppSettings();
        return false;
      }
      // First ask (or plain denied): show the rationale, then request.
      final proceed = await _rationaleDialog(context, label, reason);
      if (proceed != true) return false;
      final next = await permission.request();
      return next == PermissionStatus.granted ||
          next == PermissionStatus.limited;
    } catch (_) {
      return false;
    }
  }

  Future<bool?> _rationaleDialog(
      BuildContext context, String label, String reason) {
    return showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('$label permission'),
        content: Text(reason),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(c).pop(false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(c).pop(true),
              child: const Text('Continue')),
        ],
      ),
    );
  }

  Future<bool?> _settingsDialog(BuildContext context, String label) {
    return showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('$label permission needed'),
        content: Text(
            'GoTRVL needs $label access for this feature, but it was turned '
            'off. You can enable it in your device settings.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(c).pop(false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(c).pop(true),
              child: const Text('Open Settings')),
        ],
      ),
    );
  }
}
