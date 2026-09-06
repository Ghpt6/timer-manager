import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'timer_models.dart';
import 'timer_platform.dart';

class TimerController extends ChangeNotifier {
  TimerController({required this.platform, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final TimerPlatform platform;
  final DateTime Function() _now;
  final List<TimerPreset> _presets = [...defaultPresets];
  final List<TimerCategory> _categories = [...defaultCategories];
  final List<ActiveTimer> _timers = [];
  Timer? _ticker;
  Future<void> _pendingSave = Future.value();
  bool _disposed = false;
  bool _initializing = false;
  int _nextId = 10;
  int _nextCategoryId = 7;
  bool loaded = false;
  String? error;
  String? warning;

  List<TimerPreset> get presets => List.unmodifiable(_presets);
  List<TimerCategory> get categories => List.unmodifiable(_categories);
  List<ActiveTimer> get timers => List.unmodifiable(_timers);
  DateTime get now => _now();
  int get runningCount =>
      _timers.where((timer) => timer.status == TimerStatus.running).length;
  Future<void> get saved => _pendingSave;

  TimerCategory? categoryFor(int? id) {
    for (final category in _categories) {
      if (category.id == id) return category;
    }
    return null;
  }

  String categoryName(int? id) => categoryFor(id)?.name ?? '未分类';

  Future<void> initialize() async {
    if (_initializing || loaded) return;
    _initializing = true;
    var migrated = false;
    try {
      final raw = await platform.readState();
      if (_disposed) return;
      if (raw != null) {
        final state = jsonDecode(raw) as Map<String, dynamic>;
        final legacy = state['version'] == 1;
        if (!legacy && state['version'] != 2) {
          throw const FormatException('Invalid version');
        }
        final presets = (state['presets'] as List)
            .map(
              (item) => TimerPreset.fromJson(
                item as Map<String, dynamic>,
                legacy: legacy,
              ),
            )
            .toList();
        final timers = (state['timers'] as List)
            .map(
              (item) => ActiveTimer.fromJson(
                item as Map<String, dynamic>,
                legacy: legacy,
              ),
            )
            .toList();
        final categories = legacy
            ? [...legacyCategories]
            : (state['categories'] as List)
                  .map(
                    (item) =>
                        TimerCategory.fromJson(item as Map<String, dynamic>),
                  )
                  .toList();
        final categoryIds = categories.map((e) => e.id).toSet();
        if (categoryIds.length != categories.length ||
            categories.map((e) => e.name.toLowerCase()).toSet().length !=
                categories.length ||
            presets.any(
              (e) =>
                  e.categoryId != null && !categoryIds.contains(e.categoryId),
            )) {
          throw const FormatException('Invalid category references');
        }
        if (presets.map((e) => e.id).toSet().length != presets.length ||
            timers.map((e) => e.id).toSet().length != timers.length) {
          throw const FormatException('Duplicate timer IDs');
        }
        var nextId = state['nextId'] as int;
        var nextCategoryId = legacy ? 4 : state['nextCategoryId'] as int;
        if (nextId < 1 || nextCategoryId < 1) {
          throw const FormatException('Invalid next ID');
        }
        for (final id in [
          ...presets.map((e) => e.id),
          ...timers.map((e) => e.id),
        ]) {
          if (nextId <= id) nextId = id + 1;
        }
        // Active snapshots may refer to deleted categories; never reuse those IDs.
        for (final id in [
          ...categoryIds,
          ...timers.map((e) => e.preset.categoryId).whereType<int>(),
        ]) {
          if (nextCategoryId <= id) nextCategoryId = id + 1;
        }
        _nextId = nextId;
        _nextCategoryId = nextCategoryId;
        _categories
          ..clear()
          ..addAll(categories);
        _presets
          ..clear()
          ..addAll(presets);
        _timers.addAll(timers);
        migrated = legacy;
      }
    } catch (_) {
      error = '无法读取本地记录，已显示默认计时。';
    }
    if (_disposed) return;
    loaded = true;
    refresh();
    if (migrated) _persist();
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (runningCount > 0) refresh();
    });
    await refreshWarning();
  }

  ActiveTimer? timerFor(int id) {
    for (final timer in _timers) {
      if (timer.id == id) return timer;
    }
    return null;
  }

  void start(TimerPreset preset) {
    if (!loaded) return;
    final current = timerFor(preset.id);
    if (current?.status == TimerStatus.running) return;
    if (current?.status == TimerStatus.paused) {
      resume(preset.id);
      return;
    }
    _timers.removeWhere((timer) => timer.id == preset.id);
    _timers.insert(
      0,
      ActiveTimer(
        preset: preset,
        status: TimerStatus.running,
        remainingMilliseconds: preset.seconds * 1000,
        deadline: now.add(Duration(seconds: preset.seconds)),
      ),
    );
    _changed();
    unawaited(_enableReminders());
  }

  void pause(int id) {
    final timer = timerFor(id);
    if (timer == null || timer.status != TimerStatus.running) return;
    final remaining = timer.remainingAt(now);
    _replace(
      ActiveTimer(
        preset: timer.preset,
        status: remaining == 0 ? TimerStatus.completed : TimerStatus.paused,
        remainingMilliseconds: remaining,
        deadline: remaining == 0 ? timer.deadline : null,
      ),
    );
  }

  void resume(int id) {
    final timer = timerFor(id);
    if (timer == null || timer.status != TimerStatus.paused) return;
    _replace(
      ActiveTimer(
        preset: timer.preset,
        status: TimerStatus.running,
        remainingMilliseconds: timer.remainingMilliseconds,
        deadline: now.add(Duration(milliseconds: timer.remainingMilliseconds)),
      ),
    );
  }

  /// Reset restores the original duration and leaves the timer paused.
  void reset(int id) {
    final timer = timerFor(id);
    if (timer == null) return;
    _replace(
      ActiveTimer(
        preset: timer.preset,
        status: TimerStatus.paused,
        remainingMilliseconds: timer.preset.seconds * 1000,
      ),
    );
  }

  void dismiss(int id) {
    _timers.removeWhere((timer) => timer.id == id);
    _changed();
  }

  TimerPreset savePreset({
    int? id,
    required String name,
    required int seconds,
    required TaskIcon kind,
    int? categoryId,
  }) {
    final trimmed = name.trim();
    if (trimmed.isEmpty ||
        trimmed.length > 20 ||
        seconds < 1 ||
        seconds > 359999) {
      throw ArgumentError('请输入名称和有效时长');
    }
    if (categoryId != null && categoryFor(categoryId) == null) {
      throw ArgumentError('请选择有效分类');
    }
    final preset = TimerPreset(
      id: id ?? _nextId++,
      name: trimmed,
      seconds: seconds,
      kind: kind,
      categoryId: categoryId,
    );
    if (_nextId <= preset.id) _nextId = preset.id + 1;
    final index = _presets.indexWhere((item) => item.id == id);
    if (index == -1) {
      _presets.add(preset);
    } else {
      _presets[index] = preset;
    }
    _changed();
    return preset;
  }

  TimerCategory saveCategory({int? id, required String name}) {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed.length > 20) {
      throw ArgumentError('分类名称须为 1–20 个字符');
    }
    if (trimmed == '全部' || trimmed == '未分类') {
      throw ArgumentError('请使用「全部」「未分类」以外的名称');
    }
    if (_categories.any(
      (e) => e.id != id && e.name.toLowerCase() == trimmed.toLowerCase(),
    )) {
      throw ArgumentError('分类名称已存在');
    }
    final index = _categories.indexWhere((e) => e.id == id);
    if (id != null && index < 0) throw ArgumentError('分类不存在');
    final category = TimerCategory(id: id ?? _nextCategoryId++, name: trimmed);
    if (index < 0) {
      _categories.add(category);
    } else {
      _categories[index] = category;
    }
    _changed();
    return category;
  }

  /// Removing a category preserves tasks and all active timer snapshots.
  void deleteCategory(int id) {
    if (categoryFor(id) == null) return;
    _categories.removeWhere((e) => e.id == id);
    for (var i = 0; i < _presets.length; i++) {
      if (_presets[i].categoryId == id) {
        _presets[i] = _presets[i].withCategory(null);
      }
    }
    _changed();
  }

  void deletePreset(int id) {
    _presets.removeWhere((preset) => preset.id == id);
    _changed();
  }

  void refresh() {
    if (_disposed) return;
    var completed = false;
    final instant = now;
    for (var i = 0; i < _timers.length; i++) {
      final timer = _timers[i];
      if (timer.status == TimerStatus.running &&
          timer.remainingAt(instant) == 0) {
        _timers[i] = ActiveTimer(
          preset: timer.preset,
          status: TimerStatus.completed,
          remainingMilliseconds: 0,
          deadline: timer.deadline,
        );
        completed = true;
      }
    }
    if (completed) _persist();
    notifyListeners();
  }

  Future<void> _enableReminders() async {
    try {
      await platform.requestNotifications();
      await refreshWarning();
    } catch (_) {
      if (_disposed) return;
      warning = '系统提醒暂不可用，请保持应用开启。';
      notifyListeners();
    }
  }

  Future<void> refreshWarning() async {
    try {
      final value = await platform.reminderWarning();
      if (_disposed) return;
      warning = value;
    } catch (_) {
      if (_disposed) return;
      warning = '系统提醒暂不可用，请保持应用开启。';
    }
    notifyListeners();
  }

  Future<void> openReminderSettings() async {
    try {
      await platform.openReminderSettings();
    } catch (_) {
      if (_disposed) return;
      error = '无法打开设置，请在系统设置中允许计时管理发送通知。';
      notifyListeners();
    }
  }

  void clearError() {
    error = null;
    notifyListeners();
  }

  void _replace(ActiveTimer timer) {
    _timers[_timers.indexWhere((item) => item.id == timer.id)] = timer;
    _changed();
  }

  void _changed() {
    _persist();
    notifyListeners();
  }

  void _persist() {
    final state = jsonEncode({
      'version': 2,
      'nextId': _nextId,
      'nextCategoryId': _nextCategoryId,
      'categories': _categories.map((item) => item.toJson()).toList(),
      'presets': _presets.map((item) => item.toJson()).toList(),
      'timers': _timers.map((item) => item.toJson()).toList(),
    });
    // Serialize snapshots so rapid taps cannot let stale saves overwrite pauses.
    _pendingSave = _pendingSave.then((_) async {
      try {
        await platform.saveState(state);
      } catch (_) {
        if (_disposed) return;
        error = '保存或设置提醒失败，请保持应用开启后重试。';
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _ticker?.cancel();
    super.dispose();
  }
}
