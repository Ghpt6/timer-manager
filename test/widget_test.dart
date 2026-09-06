import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutterproject/main.dart';
import 'package:flutterproject/src/timer_controller.dart';
import 'package:flutterproject/src/timer_models.dart';

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

  testWidgets('one tap starts, pause resume reset and cancel work', (
    tester,
  ) async {
    final controller = await launch(tester);
    expect(find.text('05:10'), findsOneWidget);
    expect(find.text('11:40'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('preset-1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('active-1')), findsOneWidget);
    expect(controller.runningCount, 1);
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
