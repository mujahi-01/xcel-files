import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'directory_rename.dart';

/// Unique task name for the 4-hour auto turn-off job.
const String kAutoTurnOffTask = 'xcel_auto_turn_off';

/// Top-level callback required by Workmanager.
///
/// This function runs in a separate Dart isolate spawned by the native
/// Workmanager plugin.  It must be a top-level (or static) function.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    if (taskName == kAutoTurnOffTask) {
      // Perform the TURN OFF rename using the synchronous helper.
      final result = turnOffRenameSync();

      // Update SharedPreferences so the UI reflects OFF state on next open.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isOn', false);

      // Return true whether or not rename succeeded so Workmanager doesn't
      // retry (the rename may legitimately be a no-op if already off).
      return true;
    }
    // Unknown task – return false to signal failure (won't retry by default).
    return false;
  });
}

/// Schedules a one-shot Workmanager task to run exactly 4 hours from now.
Future<void> scheduleAutoTurnOff() async {
  // Cancel any previously scheduled task first to avoid duplicates.
  await Workmanager().cancelByUniqueName(kAutoTurnOffTask);

  await Workmanager().registerOneOffTask(
    kAutoTurnOffTask,
    kAutoTurnOffTask,
    initialDelay: const Duration(hours: 4),
    constraints: Constraints(
      // Run even without network; we only do local file I/O.
      networkType: NetworkType.not_required,
    ),
    existingWorkPolicy: ExistingWorkPolicy.replace,
  );
}

/// Cancels the scheduled auto turn-off task (called on manual TURN OFF).
Future<void> cancelAutoTurnOff() async {
  await Workmanager().cancelByUniqueName(kAutoTurnOffTask);
}
