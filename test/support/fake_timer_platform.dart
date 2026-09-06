import 'package:flutterproject/src/timer_platform.dart';

class FakeTimerPlatform implements TimerPlatform {
  String? state;
  bool failSave = false;
  int saves = 0;
  String? warning;

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
