import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutterproject/src/timer_controller.dart';
import 'package:flutterproject/src/timer_models.dart';

import 'support/fake_timer_platform.dart';

void main() {
  late DateTime now;
  late FakeTimerPlatform platform;
  late TimerController controller;

  setUp(() async {
    now = DateTime(2026, 9, 6, 12);
    platform = FakeTimerPlatform();
    controller = TimerController(platform: platform, now: () => now);
    await controller.initialize();
  });
  tearDown(() => controller.dispose());

  test(
    'welcome is shown only on the first visit, even without starting',
    () async {
      expect(controller.showWelcome, isTrue);
      await controller.saved;
      controller.dispose();
      controller = TimerController(platform: platform, now: () => now);
      await controller.initialize();
      expect(controller.showWelcome, isFalse);
      expect(controller.presets.length, defaultPresets.length);
      expect(controller.timers, isEmpty);
    },
  );

  test(
    'starting permanently hides welcome after reset, cancel and relaunch',
    () async {
      controller.start(controller.presets.first);
      expect(controller.showWelcome, isFalse);
      controller.reset(1);
      controller.dismiss(1);
      expect(controller.showWelcome, isFalse);
      await controller.saved;
      controller.dispose();
      controller = TimerController(platform: platform, now: () => now);
      await controller.initialize();
      expect(controller.showWelcome, isFalse);
    },
  );

  test('required presets start immediately and run independently', () {
    expect(controller.presets[0].seconds, 310);
    expect(controller.presets[1].seconds, 700);
    controller.start(controller.presets[0]);
    now = now.add(const Duration(seconds: 10));
    controller.start(controller.presets[1]);
    expect(controller.timerFor(1)!.secondsAt(now), 300);
    expect(controller.timerFor(2)!.secondsAt(now), 700);
    controller.start(controller.presets[0]);
    expect(controller.timers.length, 2);
    expect(controller.timerFor(1)!.secondsAt(now), 300);
  });

  test('pause preserves milliseconds, resume excludes paused time', () {
    controller.start(controller.presets[0]);
    now = now.add(const Duration(milliseconds: 2250));
    controller.pause(1);
    expect(controller.timerFor(1)!.remainingAt(now), 307750);
    now = now.add(const Duration(minutes: 20));
    expect(controller.timerFor(1)!.remainingAt(now), 307750);
    controller.resume(1);
    now = now.add(const Duration(milliseconds: 750));
    expect(controller.timerFor(1)!.secondsAt(now), 307);
    controller.reset(1);
    expect(controller.timerFor(1)!.status, TimerStatus.paused);
    expect(controller.timerFor(1)!.secondsAt(now), 310);
  });

  test('long background gap completes every elapsed timer once', () async {
    controller.start(controller.presets[0]);
    controller.start(controller.presets[1]);
    now = now.add(const Duration(hours: 1));
    controller.refresh();
    expect(
      controller.timers.every((e) => e.status == TimerStatus.completed),
      isTrue,
    );
    expect(controller.runningCount, 0);
    await controller.saved;
    final saves = platform.saves;
    controller.refresh();
    await controller.saved;
    expect(platform.saves, saves);
    expect(controller.timers.every((e) => e.secondsAt(now) == 0), isTrue);
  });

  test('reopening restores deadlines and paused remaining time', () async {
    controller.start(controller.presets[0]);
    controller.start(controller.presets[1]);
    now = now.add(const Duration(seconds: 20));
    controller.pause(2);
    await controller.saved;
    controller.dispose();
    now = now.add(const Duration(minutes: 2));
    controller = TimerController(platform: platform, now: () => now);
    await controller.initialize();
    expect(controller.timerFor(1)!.secondsAt(now), 170);
    expect(controller.timerFor(2)!.secondsAt(now), 680);
    expect(controller.timerFor(2)!.status, TimerStatus.paused);
  });

  test('expired timer is completed on launch and can start again', () async {
    controller.start(controller.presets.first);
    await controller.saved;
    controller.dispose();
    now = now.add(const Duration(minutes: 10));
    controller = TimerController(platform: platform, now: () => now);
    await controller.initialize();
    expect(controller.timerFor(1)!.status, TimerStatus.completed);
    controller.start(controller.presets.first);
    expect(controller.timerFor(1)!.secondsAt(now), 310);
    expect(controller.timerFor(1)!.status, TimerStatus.running);
  });

  test('editing and deleting a preset preserve its current timer', () {
    controller.start(controller.presets.first);
    controller.savePreset(id: 1, name: '新烧水', seconds: 30, kind: TaskIcon.tea);
    expect(controller.timerFor(1)!.preset.name, '烧水');
    expect(controller.timerFor(1)!.secondsAt(now), 310);
    controller.deletePreset(1);
    expect(controller.timerFor(1), isNotNull);
    controller.dismiss(1);
    expect(controller.timers, isEmpty);
  });

  test('empty preset list remains empty after reopening', () async {
    for (final preset in controller.presets) {
      controller.deletePreset(preset.id);
    }
    await controller.saved;
    controller.dispose();
    controller = TimerController(platform: platform, now: () => now);
    await controller.initialize();
    expect(controller.presets, isEmpty);
  });

  test('new presets validate names and durations', () {
    for (final seconds in [0, -1, 360000]) {
      expect(
        () => controller.savePreset(
          name: '测试',
          seconds: seconds,
          kind: TaskIcon.egg,
        ),
        throwsArgumentError,
      );
    }
    expect(
      () => controller.savePreset(name: '  ', seconds: 10, kind: TaskIcon.egg),
      throwsArgumentError,
    );
    controller.savePreset(name: '  蒸鱼  ', seconds: 750, kind: TaskIcon.rice);
    expect(controller.presets.last.name, '蒸鱼');
    expect(controller.presets.last.seconds, 750);
  });

  test('rapid start pause reset dismiss persists the final state', () async {
    controller.start(controller.presets.first);
    controller.pause(1);
    controller.resume(1);
    controller.reset(1);
    controller.dismiss(1);
    await controller.saved;
    expect(jsonDecode(platform.state!)['timers'], isEmpty);
    expect(platform.saves, 6);
  });

  test(
    'failed storage reports error and subsequent save can succeed',
    () async {
      platform.failSave = true;
      controller.start(controller.presets.first);
      await controller.saved;
      expect(controller.error, contains('失败'));
      platform.failSave = false;
      controller.pause(1);
      await controller.saved;
      expect(jsonDecode(platform.state!)['timers'][0]['status'], 'paused');
    },
  );

  test('malformed saved state falls back safely', () async {
    controller.dispose();
    platform.state = '{broken';
    controller = TimerController(platform: platform, now: () => now);
    await controller.initialize();
    expect(controller.loaded, isTrue);
    expect(controller.presets.length, defaultPresets.length);
    expect(controller.error, contains('无法读取'));
  });

  test('time labels handle seconds, minutes and hours', () {
    expect(clockText(310), '05:10');
    expect(clockText(700), '11:40');
    expect(clockText(3601), '01:00:01');
    expect(durationText(310), '5分10秒');
    expect(durationText(3600), '1小时');
  });

  test(
    'custom tasks and independent category assignments survive reopening',
    () async {
      final category = controller.saveCategory(name: '  学习  ');
      final task = controller.savePreset(
        name: '阅读',
        seconds: 2400,
        kind: TaskIcon.study,
        categoryId: category.id,
      );
      controller.start(task);
      final deadline = controller.timerFor(task.id)!.deadline;
      controller.savePreset(
        id: task.id,
        name: '阅读训练',
        seconds: 900,
        kind: TaskIcon.running,
        categoryId: category.id,
      );
      controller.saveCategory(id: category.id, name: '个人成长');
      expect(controller.presets.last.categoryId, category.id);
      expect(controller.categoryName(category.id), '个人成长');
      await controller.saved;
      controller.dispose();
      controller = TimerController(platform: platform, now: () => now);
      await controller.initialize();
      expect(controller.error, isNull);
      expect(controller.presets.last.kind, TaskIcon.running);
      expect(controller.presets.last.categoryId, category.id);
      expect(controller.categoryName(category.id), '个人成长');
      expect(controller.timerFor(task.id)!.preset.name, '阅读');
      expect(controller.timerFor(task.id)!.deadline, deadline);
      expect(
        controller.saveCategory(name: '另一分类').id,
        greaterThan(category.id),
      );
    },
  );

  test(
    'moving and deleting categories preserves tasks and running snapshots',
    () async {
      final first = controller.presets.first;
      controller.start(first);
      now = now.add(const Duration(seconds: 12));
      controller.savePreset(
        id: first.id,
        name: first.name,
        seconds: first.seconds,
        kind: first.kind,
        categoryId: 4,
      );
      final count = controller.presets.length;
      controller.deleteCategory(4);
      expect(controller.presets.length, count);
      expect(controller.presets.first.categoryId, isNull);
      expect(controller.timerFor(first.id)!.preset.categoryId, 1);
      expect(controller.timerFor(first.id)!.secondsAt(now), 298);
      controller.deleteCategory(1);
      await controller.saved;
      controller.dispose();
      controller = TimerController(platform: platform, now: () => now);
      await controller.initialize();
      expect(controller.error, isNull);
      expect(controller.categoryFor(1), isNull);
      expect(controller.categoryFor(4), isNull);
      expect(controller.timerFor(first.id)!.secondsAt(now), 298);
      expect(controller.presets.first.categoryId, isNull);
    },
  );

  test('category validation rejects invalid names and missing assignments', () {
    final category = controller.saveCategory(name: 'HIIT');
    for (final name in ['', '  ', '全部', '未分类', 'hiit', '日常', '长' * 21]) {
      expect(() => controller.saveCategory(name: name), throwsArgumentError);
    }
    controller.saveCategory(id: category.id, name: 'HIIT');
    expect(
      () => controller.saveCategory(id: 999, name: '不存在'),
      throwsArgumentError,
    );
    expect(
      () => controller.savePreset(
        name: '测试',
        seconds: 60,
        kind: TaskIcon.timer,
        categoryId: 999,
      ),
      throwsArgumentError,
    );
    controller.savePreset(name: '自由任务', seconds: 60, kind: TaskIcon.timer);
    expect(controller.presets.last.categoryId, isNull);
  });

  test(
    'deleting all categories persists an empty list and uncategorized tasks',
    () async {
      for (final category in controller.categories) {
        controller.deleteCategory(category.id);
      }
      await controller.saved;
      controller.dispose();
      controller = TimerController(platform: platform, now: () => now);
      await controller.initialize();
      expect(controller.categories, isEmpty);
      expect(controller.presets.every((e) => e.categoryId == null), isTrue);
      final category = controller.saveCategory(name: '新开始');
      expect(category.id, greaterThan(6));
    },
  );

  test('version 1 migrates original tasks and active timers without resetting deadlines', () async {
    final deadline = now.add(const Duration(minutes: 3));
    Map<String, dynamic> legacyPreset(TimerPreset preset) =>
        preset.toJson()..remove('categoryId');
    platform.state = jsonEncode({
      'version': 1,
      'nextId': 2,
      'presets': defaultPresets.take(6).map(legacyPreset).toList(),
      'timers': [
        {
          'preset': legacyPreset(defaultPresets.first),
          'status': 'running',
          'remainingMilliseconds': 310000,
          'deadline': deadline.millisecondsSinceEpoch,
        },
        {
          'preset': {'id': 42, 'name': '旧自定义任务', 'seconds': 120, 'kind': 'tea'},
          'status': 'paused',
          'remainingMilliseconds': 34567,
          'deadline': null,
        },
      ],
    });
    controller.dispose();
    controller = TimerController(platform: platform, now: () => now);
    await controller.initialize();
    await controller.saved;
    expect(controller.error, isNull);
    expect(controller.presets.length, 6);
    expect(controller.showWelcome, isFalse);
    expect(controller.categories.map((e) => e.name), ['日常', '烹饪', '饮品']);
    expect(controller.presets.map((e) => e.categoryId), [1, 2, 2, 3, 2, 2]);
    expect(controller.timerFor(1)!.deadline, deadline);
    expect(controller.timerFor(42)!.remainingAt(now), 34567);
    expect(controller.timerFor(42)!.preset.categoryId, 3);
    expect(jsonDecode(platform.state!)['version'], 2);
    final task = controller.savePreset(
      name: '新任务',
      seconds: 1,
      kind: TaskIcon.timer,
    );
    expect(task.id, 43);
  });

  test('an empty version 1 task library stays empty after migration', () async {
    platform.state = jsonEncode({
      'version': 1,
      'nextId': 7,
      'presets': [],
      'timers': [],
    });
    controller.dispose();
    controller = TimerController(platform: platform, now: () => now);
    await controller.initialize();
    expect(controller.presets, isEmpty);
    expect(controller.error, isNull);
  });

  test(
    'invalid version 2 category records do not partially load state',
    () async {
      final state = {
        'version': 2,
        'nextId': 100,
        'nextCategoryId': 100,
        'categories': [
          {'id': 1, 'name': '重复'},
          {'id': 1, 'name': '另一分类'},
        ],
        'presets': [defaultPresets.first.toJson()],
        'timers': [],
      };
      platform.state = jsonEncode(state);
      controller.dispose();
      controller = TimerController(platform: platform, now: () => now);
      await controller.initialize();
      expect(controller.error, contains('无法读取'));
      expect(controller.categories.length, defaultCategories.length);
      expect(controller.presets.length, defaultPresets.length);
    },
  );
}
