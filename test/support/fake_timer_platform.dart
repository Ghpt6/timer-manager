import 'package:flutterproject/src/timer_platform.dart';

class FakeTimerPlatform implements TimerPlatform {
  String? state;
  bool failSave = false;
  int saves = 0;
  String? warning;
  TimerRingtone ringtone = const TimerRingtone.builtIn();
  TimerRingtone? nextRingtone;
  Object? ringtoneError;
  int ringtonePicks = 0;

  @override
  Future<TimerRingtone> readRingtone() async {
    if (ringtoneError != null) throw ringtoneError!;
    return ringtone;
  }

  @override
  Future<TimerRingtone?> pickRingtone() async {
    ringtonePicks++;
    if (ringtoneError != null) throw ringtoneError!;
    if (nextRingtone != null) ringtone = nextRingtone!;
    return nextRingtone;
  }

  @override
  Future<TimerRingtone> resetRingtone() async {
    if (ringtoneError != null) throw ringtoneError!;
    return ringtone = const TimerRingtone.builtIn();
  }

  @override
  Future<String?> readState() async => state;
  @override
  Future<void> saveState(String state) async {
    if (failSave) throw StateError('Storage unavailable');
    this.state = state;
    saves++;
  }

  @override
  Future<bool> requestNotifications() async => true;
  @override
  Future<String?> reminderWarning() async => warning;
  @override
  Future<void> openReminderSettings() async {}
}
