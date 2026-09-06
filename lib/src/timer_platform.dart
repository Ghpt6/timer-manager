import 'package:flutter/services.dart';

abstract class TimerPlatform {
  Future<String?> readState();
  Future<void> saveState(String state);
  Future<bool> requestNotifications();
  Future<String?> reminderWarning();
  Future<void> openReminderSettings();
}

/// Saving also synchronizes native alarms, including cancellation on pause.
class AndroidTimerPlatform implements TimerPlatform {
  const AndroidTimerPlatform();
  static const _channel = MethodChannel('kitchen_timer/platform');

  @override
  Future<String?> readState() => _channel.invokeMethod<String>('readState');
  @override
  Future<void> saveState(String state) =>
      _channel.invokeMethod<void>('saveState', state);
  @override
  Future<bool> requestNotifications() async =>
      await _channel.invokeMethod<bool>('requestNotifications') ?? false;
  @override
  Future<String?> reminderWarning() =>
      _channel.invokeMethod<String>('reminderWarning');
  @override
  Future<void> openReminderSettings() =>
      _channel.invokeMethod<void>('openReminderSettings');
}
