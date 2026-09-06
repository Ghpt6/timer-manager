import 'package:flutter/services.dart';

class TimerRingtone {
  const TimerRingtone({required this.title, this.uri});
  const TimerRingtone.builtIn() : title = '内置铃声', uri = null;

  final String title;
  final String? uri;
  bool get isBuiltIn => uri == null;

  factory TimerRingtone.fromMap(Map<Object?, Object?> map) =>
      TimerRingtone(title: map['title'] as String, uri: map['uri'] as String?);
}

abstract class TimerPlatform {
  Future<String?> readState();
  Future<void> saveState(String state);
  Future<bool> requestNotifications();
  Future<String?> reminderWarning();
  Future<void> openReminderSettings();
  Future<TimerRingtone> readRingtone();
  Future<TimerRingtone?> pickRingtone();
  Future<TimerRingtone> resetRingtone();
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

  @override
  Future<TimerRingtone> readRingtone() async => TimerRingtone.fromMap(
    (await _channel.invokeMapMethod<Object?, Object?>('readRingtone'))!,
  );

  @override
  Future<TimerRingtone?> pickRingtone() async {
    final result = await _channel.invokeMapMethod<Object?, Object?>(
      'pickRingtone',
    );
    return result == null ? null : TimerRingtone.fromMap(result);
  }

  @override
  Future<TimerRingtone> resetRingtone() async => TimerRingtone.fromMap(
    (await _channel.invokeMapMethod<Object?, Object?>('resetRingtone'))!,
  );
}
