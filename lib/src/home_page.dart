import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'category_manager.dart';
import 'task_art.dart';
import 'preset_editor.dart';
import 'theme.dart';
import 'timer_controller.dart';
import 'timer_models.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.controller});
  final TimerController controller;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final _scrollController = ScrollController();
  final _activeKey = GlobalKey();
  // -1 = all, 0 = uncategorized; positive values are stable category IDs.
  int _category = -1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.controller.refresh();
      widget.controller.refreshWarning();
    }
  }

  void _start(TimerPreset preset) {
    HapticFeedback.lightImpact();
    widget.controller.start(preset);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final activeContext = _activeKey.currentContext;
      if (activeContext != null) {
        Scrollable.ensureVisible(
          activeContext,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          alignment: .04,
        );
      }
    });
  }

  void _help() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('安排好每一段时间'),
        content: const Text(
          '轻点任务卡片，立即开始倒计时。健身、运动、工作、烹饪等任务可以同时进行。\n\n计时中可以暂停、继续或重置；重置后会等待你再次开始。\n\n点击「添加任务」自定义名称、时长、图标和分类。卡片右上角的「⋯」可以编辑或删除任务。\n\n在「管理分类」中新建、重命名或删除分类；删除分类会将任务移到「未分类」。\n\n首次开始时请允许通知，以便锁屏后收到到时提醒。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  Future<void> _editPreset([TimerPreset? preset]) async {
    final result = await showPresetEditor(
      context,
      widget.controller,
      preset: preset,
      initialCategoryId: _category > 0 ? _category : null,
    );
    if (!mounted || result == null) return;
    setState(() {
      if (preset == null || _category != -1) _category = result.categoryId ?? 0;
    });
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final controller = widget.controller;
      if (_category > 0 && controller.categoryFor(_category) == null) {
        _category = -1;
      }
      final filters = <int, String>{
        -1: '全部',
        for (final category in controller.categories)
          category.id: category.name,
        0: '未分类',
      };
      final presets = controller.presets
          .where(
            (preset) =>
                _category == -1 || (preset.categoryId ?? 0) == _category,
          )
          .toList();
      return Scaffold(
        body: SafeArea(
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 840),
              child: !controller.loaded
                  ? const Center(child: CircularProgressIndicator())
                  : CustomScrollView(
                      controller: _scrollController,
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(24, 20, 16, 0),
                          sliver: SliverToBoxAdapter(
                            child: _header(controller),
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                          sliver: SliverToBoxAdapter(child: _hero()),
                        ),
                        if (controller.error != null)
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                            sliver: SliverToBoxAdapter(
                              child: _notice(
                                controller.error!,
                                action: '关闭',
                                onTap: controller.clearError,
                              ),
                            ),
                          ),
                        if (controller.warning != null &&
                            controller.timers.isNotEmpty)
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                            sliver: SliverToBoxAdapter(
                              child: _notice(
                                controller.warning!,
                                action: '设置',
                                onTap: controller.openReminderSettings,
                              ),
                            ),
                          ),
                        if (controller.timers.isNotEmpty)
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(24, 26, 24, 0),
                            sliver: SliverToBoxAdapter(
                              child: Column(
                                key: _activeKey,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const _SectionTitle('我的计时'),
                                      const SizedBox(width: 8),
                                      _CountBadge(controller.timers.length),
                                      const Spacer(),
                                      const Icon(
                                        Icons.timelapse_rounded,
                                        size: 15,
                                        color: TimerColors.muted,
                                      ),
                                      const SizedBox(width: 4),
                                      const Text(
                                        '多任务同时计时',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: TimerColors.muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  for (final timer in controller.timers)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 12,
                                      ),
                                      child: _ActiveTimerCard(
                                        timer: timer,
                                        now: controller.now,
                                        onPause: () =>
                                            controller.pause(timer.id),
                                        onResume: () =>
                                            controller.resume(timer.id),
                                        onReset: () =>
                                            controller.reset(timer.id),
                                        onDismiss: () =>
                                            controller.dismiss(timer.id),
                                        onRestart: () =>
                                            controller.start(timer.preset),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
                          sliver: SliverToBoxAdapter(
                            child: Row(
                              children: [
                                const _SectionTitle('常用任务'),
                                const SizedBox(width: 8),
                                _CountBadge(controller.presets.length),
                                const Spacer(),
                                TextButton.icon(
                                  key: const ValueKey('manage-categories'),
                                  onPressed: () =>
                                      showCategoryManager(context, controller),
                                  icon: const Icon(
                                    Icons.folder_outlined,
                                    size: 16,
                                  ),
                                  label: const Text('管理分类'),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          sliver: SliverToBoxAdapter(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  for (final category in filters.entries)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 10),
                                      child: ChoiceChip(
                                        key: ValueKey('filter-${category.key}'),
                                        label: Text(category.value),
                                        selected: _category == category.key,
                                        onSelected: (_) => setState(
                                          () => _category = category.key,
                                        ),
                                        showCheckmark: false,
                                        selectedColor: TimerColors.ink,
                                        backgroundColor: Colors.transparent,
                                        side: BorderSide(
                                          color: _category == category.key
                                              ? TimerColors.ink
                                              : TimerColors.line,
                                        ),
                                        labelStyle: TextStyle(
                                          color: _category == category.key
                                              ? Colors.white
                                              : TimerColors.muted,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 5,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            30,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
                          sliver: SliverToBoxAdapter(
                            child: presets.isEmpty
                                ? _emptyPresets()
                                : LayoutBuilder(
                                    builder: (context, constraints) {
                                      final scale = MediaQuery.textScalerOf(
                                        context,
                                      ).scale(1);
                                      final columns =
                                          constraints.maxWidth >= 650 ? 3 : 2;
                                      final width =
                                          (constraints.maxWidth -
                                              14 * (columns - 1)) /
                                          columns;
                                      return Wrap(
                                        spacing: 14,
                                        runSpacing: 14,
                                        children: [
                                          for (final preset in presets)
                                            SizedBox(
                                              width: width,
                                              child: _PresetCard(
                                                preset: preset,
                                                categoryName: controller
                                                    .categoryName(
                                                      preset.categoryId,
                                                    ),
                                                timer: controller.timerFor(
                                                  preset.id,
                                                ),
                                                height:
                                                    238 +
                                                    (scale - 1).clamp(0, 2) *
                                                        90,
                                                onTap: () => _start(preset),
                                                onEdit: () =>
                                                    _editPreset(preset),
                                                onDelete: () =>
                                                    _deletePreset(preset),
                                              ),
                                            ),
                                        ],
                                      );
                                    },
                                  ),
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.favorite_border_rounded,
                                  size: 13,
                                  color: TimerColors.muted.withValues(
                                    alpha: .7,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Flexible(
                                  child: Text(
                                    '专注当下，从容生活',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: TimerColors.muted,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
        bottomNavigationBar: DecoratedBox(
          decoration: const BoxDecoration(
            color: TimerColors.background,
            border: Border(top: BorderSide(color: TimerColors.line)),
          ),
          child: SafeArea(
            top: false,
            child: Center(
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 840),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 14, 24, 14),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      key: const ValueKey('add-preset'),
                      onPressed: controller.loaded ? () => _editPreset() : null,
                      icon: const Icon(Icons.add_rounded, size: 23),
                      label: const Text('添加任务'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );

  Widget _header(TimerController controller) => Row(
    children: [
      Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: TimerColors.orange,
          borderRadius: BorderRadius.circular(13),
        ),
        child: const Icon(Icons.timer_outlined, color: Colors.white, size: 25),
      ),
      const SizedBox(width: 11),
      const Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '计时管理',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 20,
                letterSpacing: 1,
              ),
            ),
            Text(
              'TIMER MANAGER',
              style: TextStyle(
                fontSize: 9,
                letterSpacing: 1.7,
                color: TimerColors.muted,
              ),
            ),
          ],
        ),
      ),
      if (controller.runningCount > 0)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFE5EBE2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '${controller.runningCount} 个进行中',
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
          ),
        ),
      IconButton(
        onPressed: _help,
        tooltip: '使用说明',
        icon: const Icon(Icons.info_outline_rounded, size: 22),
        color: TimerColors.muted,
      ),
    ],
  );

  Widget _hero() => Container(
    padding: const EdgeInsets.fromLTRB(22, 22, 14, 22),
    decoration: BoxDecoration(
      color: TimerColors.cream,
      borderRadius: BorderRadius.circular(24),
    ),
    child: Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '每一种投入，都值得计时。',
                style: TextStyle(
                  color: TimerColors.muted,
                  fontSize: 11,
                  letterSpacing: .7,
                ),
              ),
              SizedBox(height: 10),
              Text(
                '不慌不忙\n刚刚好',
                style: TextStyle(
                  fontSize: 29,
                  height: 1.3,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                ),
              ),
              SizedBox(height: 13),
              Text(
                '健身 · 运动 · 工作 · 生活',
                style: TextStyle(fontSize: 12, color: TimerColors.muted),
              ),
            ],
          ),
        ),
        SizedBox(
          width: 108,
          height: 130,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 104,
                height: 104,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFF8F3E8),
                ),
              ),
              const TaskArt(kind: TaskIcon.timer, size: 106),
              Positioned(
                right: 0,
                top: 3,
                child: Transform.rotate(
                  angle: .15,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: TimerColors.background,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.access_time_rounded,
                      size: 19,
                      color: TimerColors.orange,
                    ),
                  ),
                ),
              ),
              const Positioned(
                left: 0,
                bottom: 8,
                child: Text(
                  '✦',
                  style: TextStyle(color: TimerColors.orange, fontSize: 21),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _notice(
    String text, {
    required String action,
    required VoidCallback onTap,
  }) => Container(
    padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
    decoration: BoxDecoration(
      color: const Color(0xFFFFEEDB),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.notifications_none_rounded,
          size: 19,
          color: Color(0xFF9E6136),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 12, color: Color(0xFF895531)),
          ),
        ),
        TextButton(
          onPressed: onTap,
          child: Text(action, style: const TextStyle(fontSize: 12)),
        ),
      ],
    ),
  );

  Widget _emptyPresets() => Container(
    padding: const EdgeInsets.all(32),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
    ),
    child: Column(
      children: [
        const Icon(Icons.timer_outlined, size: 36, color: TimerColors.orange),
        const SizedBox(height: 12),
        Text(
          _category == -1 ? '你的任务，你的节奏' : '这个分类还没有任务',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        const Text(
          '点击下方「添加任务」保存常用时长',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: TimerColors.muted),
        ),
      ],
    ),
  );

  void _deletePreset(TimerPreset preset) {
    widget.controller.deletePreset(preset.id);
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已删除「${preset.name}」'),
        action: SnackBarAction(
          label: '撤销',
          onPressed: () => widget.controller.savePreset(
            id: preset.id,
            name: preset.name,
            seconds: preset.seconds,
            kind: preset.kind,
            categoryId: widget.controller.categoryFor(preset.categoryId)?.id,
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
  );
}

class _CountBadge extends StatelessWidget {
  const _CountBadge(this.count);
  final int count;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: TimerColors.line,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      '$count',
      style: const TextStyle(
        color: TimerColors.muted,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _PresetCard extends StatelessWidget {
  const _PresetCard({
    required this.preset,
    required this.categoryName,
    required this.timer,
    required this.height,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });
  final TimerPreset preset;
  final String categoryName;
  final ActiveTimer? timer;
  final double height;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final running = timer?.status == TimerStatus.running;
    final paused = timer?.status == TimerStatus.paused;
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(
          color: running
              ? TimerColors.orange.withValues(alpha: .65)
              : TimerColors.line,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('preset-${preset.id}'),
        onTap: onTap,
        child: Semantics(
          button: true,
          label:
              '${preset.name}，${durationText(preset.seconds)}，${running
                  ? '查看计时'
                  : paused
                  ? '继续计时'
                  : '开始计时'}',
          child: SizedBox(
            height: height,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 62,
                        height: 62,
                        decoration: BoxDecoration(
                          color: taskTint(preset.kind),
                          borderRadius: BorderRadius.circular(19),
                        ),
                        child: TaskArt(kind: preset.kind, size: 62),
                      ),
                      const Spacer(),
                      SizedBox(
                        width: 32,
                        height: 36,
                        child: PopupMenuButton<String>(
                          key: ValueKey('menu-${preset.id}'),
                          tooltip: '管理${preset.name}',
                          padding: EdgeInsets.zero,
                          icon: const Icon(
                            Icons.more_horiz_rounded,
                            color: TimerColors.muted,
                            size: 22,
                          ),
                          onSelected: (value) =>
                              value == 'edit' ? onEdit() : onDelete(),
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit_outlined, size: 18),
                                  SizedBox(width: 10),
                                  Text('编辑'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete_outline_rounded, size: 18),
                                  SizedBox(width: 10),
                                  Text('删除'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    preset.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    categoryName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: TimerColors.muted,
                    ),
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      clockText(preset.seconds),
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -.6,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          running
                              ? '计时进行中'
                              : paused
                              ? '轻点继续'
                              : '分 : 秒${preset.seconds >= 3600 ? ' · 含小时' : ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            color: running
                                ? TimerColors.orange
                                : TimerColors.muted,
                          ),
                        ),
                      ),
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: running
                              ? TimerColors.orange
                              : const Color(0xFFFBEEE5),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          running
                              ? Icons.equalizer_rounded
                              : Icons.play_arrow_rounded,
                          color: running ? Colors.white : TimerColors.orange,
                          size: 21,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActiveTimerCard extends StatelessWidget {
  const _ActiveTimerCard({
    required this.timer,
    required this.now,
    required this.onPause,
    required this.onResume,
    required this.onReset,
    required this.onDismiss,
    required this.onRestart,
  });
  final ActiveTimer timer;
  final DateTime now;
  final VoidCallback onPause, onResume, onReset, onDismiss, onRestart;

  @override
  Widget build(BuildContext context) {
    final completed = timer.status == TimerStatus.completed;
    final paused = timer.status == TimerStatus.paused;
    final seconds = timer.secondsAt(now);
    final progress = (timer.remainingAt(now) / (timer.preset.seconds * 1000))
        .clamp(0.0, 1.0);
    return Container(
      key: ValueKey('active-${timer.id}'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: completed ? const Color(0xFFE6EEDD) : TimerColors.ink,
        borderRadius: BorderRadius.circular(24),
      ),
      child: DefaultTextStyle(
        style: TextStyle(color: completed ? TimerColors.ink : Colors.white),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  completed
                      ? Icons.check_circle_rounded
                      : Icons.timelapse_rounded,
                  color: completed ? TimerColors.ink : const Color(0xFFF0BB84),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    timer.preset.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  completed
                      ? '时间到'
                      : paused
                      ? '已暂停'
                      : '正在计时',
                  style: TextStyle(
                    fontSize: 11,
                    color: completed
                        ? TimerColors.ink
                        : const Color(0xFFC6D1C8),
                  ),
                ),
                const SizedBox(width: 5),
                SizedBox(
                  width: 32,
                  height: 32,
                  child: IconButton(
                    key: ValueKey('dismiss-${timer.id}'),
                    padding: EdgeInsets.zero,
                    onPressed: onDismiss,
                    tooltip: completed ? '关闭提醒' : '取消计时',
                    icon: Icon(
                      Icons.close_rounded,
                      size: 19,
                      color: completed
                          ? TimerColors.ink
                          : const Color(0xFFA4B4A8),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          clockText(seconds),
                          key: ValueKey('countdown-${timer.id}'),
                          style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -1,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        completed
                            ? '任务计时已完成，休息一下吧'
                            : '共 ${durationText(timer.preset.seconds)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: completed
                              ? TimerColors.ink
                              : const Color(0xFFAEBFB1),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox.square(
                  dimension: 65,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox.square(
                        dimension: 62,
                        child: CircularProgressIndicator(
                          value: completed ? 1 : progress,
                          strokeWidth: 4,
                          strokeCap: StrokeCap.round,
                          color: completed
                              ? const Color(0xFF7A9465)
                              : const Color(0xFFF0BB84),
                          backgroundColor: Colors.white.withValues(alpha: .10),
                        ),
                      ),
                      Icon(
                        completed
                            ? Icons.done_rounded
                            : paused
                            ? Icons.pause_rounded
                            : Icons.local_fire_department_outlined,
                        size: 27,
                        color: completed
                            ? const Color(0xFF7A9465)
                            : const Color(0xFFF0BB84),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    key: ValueKey('toggle-${timer.id}'),
                    onPressed: completed
                        ? onDismiss
                        : paused
                        ? onResume
                        : onPause,
                    style: FilledButton.styleFrom(
                      backgroundColor: completed
                          ? TimerColors.ink
                          : const Color(0xFFF1C699),
                      foregroundColor: completed
                          ? Colors.white
                          : TimerColors.ink,
                      minimumSize: const Size(48, 44),
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: Icon(
                      completed
                          ? Icons.check_rounded
                          : paused
                          ? Icons.play_arrow_rounded
                          : Icons.pause_rounded,
                      size: 19,
                    ),
                    label: Text(
                      completed
                          ? '完成'
                          : paused
                          ? '继续计时'
                          : '暂停',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                TextButton.icon(
                  key: ValueKey('reset-${timer.id}'),
                  onPressed: completed ? onRestart : onReset,
                  style: TextButton.styleFrom(
                    foregroundColor: completed
                        ? TimerColors.ink
                        : const Color(0xFFD6DED7),
                    minimumSize: const Size(80, 44),
                  ),
                  icon: const Icon(Icons.replay_rounded, size: 17),
                  label: Text(
                    completed ? '再来一次' : '重置',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
