import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  // Check contact permission status
  Future<PermissionStatus> checkContactPermission() async {
    return await Permission.contacts.status;
  }

  // Request contact permission
  Future<PermissionStatus> requestContactPermission() async {
    return await Permission.contacts.request();
  }

  // Check if permission is granted
  Future<bool> isContactPermissionGranted() async {
    final status = await Permission.contacts.status;
    return status.isGranted;
  }

  // Open app settings
  Future<void> openAppSettings() async {
    await openAppSettings();
  }

  // Check multiple permissions
  Future<Map<Permission, PermissionStatus>> checkPermissions(
    List<Permission> permissions,
  ) async {
    return await permissions.request();
  }
}