import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutterproject/main.dart';
import 'package:flutterproject/src/timer_controller.dart';
import 'package:flutterproject/src/timer_models.dart';
import 'package:flutterproject/src/timer_platform.dart';

import 'support/fake_timer_platform.dart';

void main() {
  Future<TimerController> launch(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    double scale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final controller = TimerController(
      platform: FakeTimerPlatform(),
      now: () => DateTime(2026, 9, 6),
    );
    await tester.pumpWidget(_OwnedApp(controller: controller));
    await tester.pumpAndSettle();
    return controller;
  }

  testWidgets(
    'global ringtone selection, cancel, reopen and reset preserve timers',
    (tester) async {
      final controller = await launch(tester);
      final platform = controller.platform as FakeTimerPlatform;
      controller.start(controller.presets.first);
      await controller.saved;
      final timer = controller.timers.single;
      final state = platform.state;
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('ringtone-settings')));
      await tester.pumpAndSettle();
      expect(find.text('内置铃声'), findsOneWidget);
      platform.nextRingtone = const TimerRingtone(
        title: '清晨鸟鸣',
        uri: 'content://media/internal/audio/media/12',
      );
      await tester.tap(find.byKey(const ValueKey('pick-ringtone')));
      await tester.pumpAndSettle();
      expect(find.text('清晨鸟鸣'), findsOneWidget);
      platform.nextRingtone = null;
      await tester.tap(find.byKey(const ValueKey('pick-ringtone')));
      await tester.pumpAndSettle();
      expect(find.text('清晨鸟鸣'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('close-ringtone-settings')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('ringtone-settings')));
      await tester.pumpAndSettle();
      expect(find.text('清晨鸟鸣'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('reset-ringtone')));
      await tester.pumpAndSettle();
      expect(find.text('内置铃声'), findsOneWidget);
      expect(controller.timers.single, same(timer));
      expect(platform.state, state);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('ringtone errors are visible and can be retried', (tester) async {
    final controller = await launch(tester);
    final platform = controller.platform as FakeTimerPlatform;
    platform.ringtoneError = PlatformException(code: 'READ', message: '无法读取铃声');
    await tester.tap(find.byKey(const ValueKey('ringtone-settings')));
    await tester.pumpAndSettle();
    expect(find.text('无法读取铃声'), findsOneWidget);
    platform.ringtoneError = null;
    await tester.tap(find.text('重新读取'));
    await tester.pumpAndSettle();
    expect(find.text('内置铃声'), findsOneWidget);
    platform.ringtoneError = PlatformException(
      code: 'RINGTONE_UNAVAILABLE',
      message: '此手机未提供系统铃声选择器',
    );
    await tester.tap(find.byKey(const ValueKey('pick-ringtone')));
    await tester.pumpAndSettle();
    expect(find.text('此手机未提供系统铃声选择器'), findsOneWidget);
    expect(find.text('内置铃声'), findsOneWidget);
    platform.ringtoneError = null;
    platform.nextRingtone = const TimerRingtone(
      title: '系统默认闹钟铃声',
      uri: 'content://settings/system/alarm_alert',
    );
    await tester.tap(find.byKey(const ValueKey('pick-ringtone')));
    await tester.pumpAndSettle();
    expect(find.text('系统默认闹钟铃声'), findsOneWidget);
    expect(find.text('此手机未提供系统铃声选择器'), findsNothing);
  });

  testWidgets(
    'ringtone settings fit 320px and double text size with a long title',
    (tester) async {
      final controller = await launch(
        tester,
        size: const Size(320, 640),
        scale: 2,
      );
      final platform = controller.platform as FakeTimerPlatform;
      platform.ringtone = const TimerRingtone(
        title: '清晨森林中悠扬的鸟鸣和流水声（手机系统自带铃声）',
        uri: 'content://media/internal/audio/media/12',
      );
      await tester.tap(find.byKey(const ValueKey('ringtone-settings')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final reset = find.byKey(const ValueKey('reset-ringtone'));
      await tester.ensureVisible(reset);
      await tester.tap(reset);
      await tester.pumpAndSettle();
      expect(platform.ringtone.isBuiltIn, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('one tap starts, pause resume reset and cancel work', (
    tester,
  ) async {
    final controller = await launch(tester);
    expect(find.text('不慌不忙\n刚刚好'), findsOneWidget);
    expect(find.text('05:10'), findsOneWidget);
    expect(find.text('11:40'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('preset-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('active-1')), findsOneWidget);
    expect(controller.runningCount, 1);
    expect(find.text('不慌不忙\n刚刚好'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('toggle-1')));
    await tester.pump();
    expect(find.text('已暂停'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('toggle-1')));
    await tester.pump();
    expect(controller.runningCount, 1);
    await tester.tap(find.byKey(const ValueKey('reset-1')));
    await tester.pump();
    expect(controller.timerFor(1)!.status, TimerStatus.paused);
    await tester.tap(find.byKey(const ValueKey('dismiss-1')));
    await tester.pumpAndSettle();
    expect(controller.timers, isEmpty);
    expect(find.text('不慌不忙\n刚刚好'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('returning from background hides the first-visit welcome', (
    tester,
  ) async {
    await launch(tester);
    expect(find.text('不慌不忙\n刚刚好'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('不慌不忙\n刚刚好'), findsNothing);
  });

  testWidgets('delete notice expires and undo works before timeout', (
    tester,
  ) async {
    final controller = await launch(
      tester,
      size: const Size(320, 740),
      scale: 1.3,
    );
    await tester.ensureVisible(find.byKey(const ValueKey('menu-1')));
    await tester.tap(find.byKey(const ValueKey('menu-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    expect(find.text('已删除「烧水」'), findsOneWidget);
    expect(controller.presets.any((preset) => preset.id == 1), isFalse);
    await tester.tap(find.text('撤销'));
    await tester.pumpAndSettle();
    expect(controller.presets.any((preset) => preset.id == 1), isTrue);
    expect(find.byType(SnackBar), findsNothing);

    await tester.ensureVisible(find.byKey(const ValueKey('menu-2')));
    await tester.tap(find.byKey(const ValueKey('menu-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    expect(find.text('已删除「煮蛋」'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
    expect(controller.presets.any((preset) => preset.id == 2), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'custom preset form rejects zero and saves exact minutes seconds',
    (tester) async {
      final controller = await launch(tester);
      await tester.tap(find.byKey(const ValueKey('add-preset')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('preset-name')), '蒸鱼');
      await tester.enterText(
        find.byKey(const ValueKey('duration-minutes')),
        '0',
      );
      await tester.tap(find.byKey(const ValueKey('save-preset')));
      await tester.pumpAndSettle();
      expect(find.text('计时时长至少为 1 秒'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('duration-minutes')),
        '12',
      );
      await tester.enterText(
        find.byKey(const ValueKey('duration-seconds')),
        '30',
      );
      await tester.tap(find.byKey(const ValueKey('save-preset')));
      await tester.pumpAndSettle();
      expect(controller.presets.last.name, '蒸鱼');
      expect(controller.presets.last.seconds, 750);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('category filtering and editing preset', (tester) async {
    final controller = await launch(tester);
    await tester.tap(find.byKey(const ValueKey('filter-3')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('preset-1')), findsNothing);
    expect(find.byKey(const ValueKey('preset-4')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('menu-4')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('编辑'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('duration-seconds')),
      '40',
    );
    await tester.tap(find.byKey(const ValueKey('save-preset')));
    await tester.pumpAndSettle();
    expect(controller.presets.firstWhere((p) => p.id == 4).seconds, 220);
  });

  testWidgets(
    '320px phone, enlarged text and active card fit without overflow',
    (tester) async {
      final controller = await launch(
        tester,
        size: const Size(320, 740),
        scale: 1.3,
      );
      expect(tester.takeException(), isNull);
      controller.start(controller.presets.first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('add-preset')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('completion remains visible until acknowledged', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var now = DateTime(2026, 9, 6);
    final controller = TimerController(
      platform: FakeTimerPlatform(),
      now: () => now,
    );
    await tester.pumpWidget(_OwnedApp(controller: controller));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('preset-1')));
    await tester.pumpAndSettle();
    now = now.add(const Duration(seconds: 310));
    controller.refresh();
    await tester.pumpAndSettle();
    expect(find.text('时间到'), findsOneWidget);
    expect(find.text('00:00'), findsOneWidget);
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();
    expect(controller.timers, isEmpty);
  });

  testWidgets(
    'create category inside task editor and save a non-kitchen task',
    (tester) async {
      final controller = await launch(tester);
      await tester.tap(find.byKey(const ValueKey('add-preset')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('preset-name')), '阅读训练');
      await tester.tap(find.byKey(const ValueKey('create-category-in-editor')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('save-category')));
      await tester.pumpAndSettle();
      expect(find.text('分类名称须为 1–20 个字符'), findsOneWidget);
      await tester.enterText(find.byKey(const ValueKey('category-name')), '日常');
      await tester.tap(find.byKey(const ValueKey('save-category')));
      await tester.pumpAndSettle();
      expect(find.text('分类名称已存在'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('category-name')),
        '个人成长',
      );
      await tester.tap(find.byKey(const ValueKey('save-category')));
      await tester.pumpAndSettle();
      final category = controller.categories.last;
      expect(
        find.byKey(ValueKey('preset-category-${category.id}')),
        findsOneWidget,
      );
      await tester.ensureVisible(find.byKey(const ValueKey('icon-work')));
      await tester.tap(find.byKey(const ValueKey('icon-work')));
      await tester.ensureVisible(find.byKey(const ValueKey('save-preset')));
      await tester.tap(find.byKey(const ValueKey('save-preset')));
      await tester.pumpAndSettle();
      final task = controller.presets.last;
      expect(task.name, '阅读训练');
      expect(task.kind, TaskIcon.work);
      expect(task.categoryId, category.id);
      expect(find.byKey(ValueKey('preset-${task.id}')), findsOneWidget);
      expect(find.byKey(const ValueKey('preset-1')), findsNothing);
      await tester.tap(find.byKey(ValueKey('preset-${task.id}')));
      await tester.pumpAndSettle();
      expect(controller.timerFor(task.id)!.status, TimerStatus.running);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'editing moves a task between categories while preserving its timer',
    (tester) async {
      final controller = await launch(tester);
      controller.start(controller.presets.first);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('filter-1')));
      await tester.tap(find.byKey(const ValueKey('filter-1')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('menu-1')));
      await tester.tap(find.byKey(const ValueKey('menu-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('编辑'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('preset-category-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('工作').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('save-preset')));
      await tester.tap(find.byKey(const ValueKey('save-preset')));
      await tester.pumpAndSettle();
      expect(controller.presets.first.categoryId, 6);
      expect(controller.timerFor(1)!.preset.categoryId, 1);
      expect(controller.timerFor(1)!.secondsAt(controller.now), 310);
      expect(
        tester
            .widget<ChoiceChip>(find.byKey(const ValueKey('filter-6')))
            .selected,
        isTrue,
      );
      expect(find.byKey(const ValueKey('preset-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('preset-2')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'manage categories renames by ID and deleting moves tasks to uncategorized',
    (tester) async {
      final controller = await launch(tester);
      await tester.tap(find.byKey(const ValueKey('filter-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('manage-categories')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('rename-category-1')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const ValueKey('category-name')), '生活');
      await tester.tap(find.byKey(const ValueKey('save-category')));
      await tester.pumpAndSettle();
      expect(controller.categoryName(1), '生活');
      expect(controller.presets.first.categoryId, 1);
      await tester.tap(find.byKey(const ValueKey('delete-category-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('confirm-delete-category')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('close-categories')));
      await tester.pumpAndSettle();
      expect(controller.categoryFor(1), isNull);
      expect(controller.presets.first.categoryId, isNull);
      expect(
        tester
            .widget<ChoiceChip>(find.byKey(const ValueKey('filter--1')))
            .selected,
        isTrue,
      );
      await tester.ensureVisible(find.byKey(const ValueKey('filter-0')));
      await tester.tap(find.byKey(const ValueKey('filter-0')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('preset-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('preset-2')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('add-preset')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('preset-category-0')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'long custom categories and form fit a narrow phone with enlarged text',
    (tester) async {
      final controller = await launch(
        tester,
        size: const Size(320, 740),
        scale: 1.3,
      );
      final category = controller.saveCategory(name: '这是一段用来验证超长分类名称的文字');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(ValueKey('filter-${category.id}')));
      await tester.tap(find.byKey(ValueKey('filter-${category.id}')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('add-preset')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(ValueKey('preset-category-${category.id}')),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const ValueKey('preset-name')),
        '我的工作任务',
      );
      await tester.ensureVisible(find.byKey(const ValueKey('save-preset')));
      await tester.tap(find.byKey(const ValueKey('save-preset')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('manage-categories')),
      );
      await tester.tap(find.byKey(const ValueKey('manage-categories')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(ValueKey('category-row-${category.id}')),
        160,
        scrollable: find.descendant(
          of: find.byType(ListView),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}

// The harness owns injected controllers and releases their periodic timers
// when Flutter disposes the tree, before checking pending timer invariants.
class _OwnedApp extends StatefulWidget {
  const _OwnedApp({required this.controller});
  final TimerController controller;
  @override
  State<_OwnedApp> createState() => _OwnedAppState();
}

class _OwnedAppState extends State<_OwnedApp> {
  @override
  Widget build(BuildContext context) =>
      TimerManagerApp(controller: widget.controller);
  @override
  void dispose() {
    widget.controller.dispose();
    super.dispose();
  }
}
