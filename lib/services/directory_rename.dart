import 'dart:io';

/// Paths used throughout the app for directory rename logic.
class AppPaths {
  // Free Fire Max game data directory
  static const String freeFire =
      '/storage/emulated/0/Android/data/com.dts.freefiremax';
  // Panel mod directory
  static const String panel =
      '/storage/emulated/0/Android/data/com.mujahi.panel';
  // Data backup directory
  static const String data =
      '/storage/emulated/0/Android/data/com.mujahi.data';
}

/// Result model returned by rename operations.
class RenameResult {
  final bool success;
  final String message;
  const RenameResult({required this.success, required this.message});
}

/// Performs the TURN ON rename sequence.
///
/// Conditions required:  $F exists, $P exists, $D does NOT exist.
/// Actions:              rename $F → $D, then rename $P → $F.
Future<RenameResult> turnOnRename() async {
  final dirF = Directory(AppPaths.freeFire);
  final dirP = Directory(AppPaths.panel);
  final dirD = Directory(AppPaths.data);

  // Guard: verify pre-conditions
  if (!dirF.existsSync()) {
    return const RenameResult(
        success: false, message: 'FreeFire directory not found.');
  }
  if (!dirP.existsSync()) {
    return const RenameResult(
        success: false, message: 'Panel directory not found.');
  }
  if (dirD.existsSync()) {
    return const RenameResult(
        success: false, message: 'Already ON (data directory already exists).');
  }

  try {
    // Step 1: rename FreeFire → Data
    await dirF.rename(AppPaths.data);
    // Step 2: rename Panel → FreeFire
    await dirP.rename(AppPaths.freeFire);
    return const RenameResult(success: true, message: 'Turned ON successfully.');
  } catch (e) {
    return RenameResult(success: false, message: 'Turn ON failed: $e');
  }
}

/// Performs the TURN OFF rename sequence.
///
/// Conditions required:  $F exists, $D exists, $P does NOT exist.
/// Actions:              rename $F → $P, then rename $D → $F.
Future<RenameResult> turnOffRename() async {
  final dirF = Directory(AppPaths.freeFire);
  final dirP = Directory(AppPaths.panel);
  final dirD = Directory(AppPaths.data);

  // Guard: verify pre-conditions
  if (!dirF.existsSync()) {
    return const RenameResult(
        success: false, message: 'FreeFire directory not found.');
  }
  if (!dirD.existsSync()) {
    return const RenameResult(
        success: false, message: 'Already OFF (data directory missing).');
  }
  if (dirP.existsSync()) {
    return const RenameResult(
        success: false,
        message: 'Already OFF (panel directory already exists).');
  }

  try {
    // Step 1: rename FreeFire → Panel
    await dirF.rename(AppPaths.panel);
    // Step 2: rename Data → FreeFire
    await dirD.rename(AppPaths.freeFire);
    return const RenameResult(
        success: true, message: 'Turned OFF successfully.');
  } catch (e) {
    return RenameResult(success: false, message: 'Turn OFF failed: $e');
  }
}

/// Synchronous version of [turnOffRename] used inside Workmanager background
/// isolate where async top-level awaits are already handled by the isolate.
RenameResult turnOffRenameSync() {
  final dirF = Directory(AppPaths.freeFire);
  final dirP = Directory(AppPaths.panel);
  final dirD = Directory(AppPaths.data);

  if (!dirF.existsSync()) {
    return const RenameResult(
        success: false, message: 'FreeFire directory not found.');
  }
  if (!dirD.existsSync()) {
    return const RenameResult(
        success: false, message: 'Already OFF.');
  }
  if (dirP.existsSync()) {
    return const RenameResult(
        success: false, message: 'Panel directory already exists.');
  }

  try {
    dirF.renameSync(AppPaths.panel);
    dirD.renameSync(AppPaths.freeFire);
    return const RenameResult(success: true, message: 'Auto-turned OFF.');
  } catch (e) {
    return RenameResult(success: false, message: 'Auto turn-off failed: $e');
  }
}
