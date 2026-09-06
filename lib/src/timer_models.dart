/// Icons are visual choices only; categories are separate, user-owned records.
enum TaskIcon {
  timer('通用'),
  fitness('健身'),
  running('运动'),
  work('工作'),
  study('学习'),
  meditation('冥想'),
  kettle('烧水'),
  egg('煮蛋'),
  noodles('煮面'),
  tea('泡茶'),
  rice('蒸饭'),
  soup('煲汤');

  const TaskIcon(this.label);
  final String label;
}

class TimerCategory {
  const TimerCategory({required this.id, required this.name});

  final int id;
  final String name;

  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  factory TimerCategory.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as int;
    final name = (json['name'] as String).trim();
    if (id < 1 ||
        name.isEmpty ||
        name.length > 20 ||
        name == '全部' ||
        name == '未分类') {
      throw const FormatException('Invalid category');
    }
    return TimerCategory(id: id, name: name);
  }
}

const legacyCategories = [
  TimerCategory(id: 1, name: '日常'),
  TimerCategory(id: 2, name: '烹饪'),
  TimerCategory(id: 3, name: '饮品'),
];

const defaultCategories = [
  ...legacyCategories,
  TimerCategory(id: 4, name: '健身'),
  TimerCategory(id: 5, name: '运动'),
  TimerCategory(id: 6, name: '工作'),
];

class TimerPreset {
  const TimerPreset({
    required this.id,
    required this.name,
    required this.seconds,
    required this.kind,
    this.categoryId,
  });

  final int id;
  final String name;
  final int seconds;
  final TaskIcon kind;
  final int? categoryId;

  TimerPreset withCategory(int? categoryId) => TimerPreset(
    id: id,
    name: name,
    seconds: seconds,
    kind: kind,
    categoryId: categoryId,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'seconds': seconds,
    'kind': kind.name,
    'categoryId': categoryId,
  };

  factory TimerPreset.fromJson(
    Map<String, dynamic> json, {
    bool legacy = false,
  }) {
    final id = json['id'] as int;
    final name = json['name'] as String;
    final seconds = json['seconds'] as int;
    if (id < 1 || name.trim().isEmpty || seconds < 1 || seconds > 359999) {
      throw const FormatException('Invalid timer preset');
    }
    final kind = TaskIcon.values.byName(json['kind'] as String);
    // Version 1 derived categories from food icons. Never infer them in v2.
    final categoryId = legacy
        ? switch (kind) {
            TaskIcon.kettle => 1,
            TaskIcon.tea => 3,
            TaskIcon.egg ||
            TaskIcon.noodles ||
            TaskIcon.rice ||
            TaskIcon.soup => 2,
            _ => null,
          }
        : json['categoryId'] as int?;
    if (categoryId != null && categoryId < 1) {
      throw const FormatException('Invalid category ID');
    }
    return TimerPreset(
      id: id,
      name: name,
      seconds: seconds,
      kind: kind,
      categoryId: categoryId,
    );
  }
}

const defaultPresets = [
  TimerPreset(
    id: 1,
    name: '烧水',
    seconds: 310,
    kind: TaskIcon.kettle,
    categoryId: 1,
  ),
  TimerPreset(
    id: 2,
    name: '煮蛋',
    seconds: 700,
    kind: TaskIcon.egg,
    categoryId: 2,
  ),
  TimerPreset(
    id: 3,
    name: '煮面',
    seconds: 360,
    kind: TaskIcon.noodles,
    categoryId: 2,
  ),
  TimerPreset(
    id: 4,
    name: '泡茶',
    seconds: 180,
    kind: TaskIcon.tea,
    categoryId: 3,
  ),
  TimerPreset(
    id: 5,
    name: '蒸米饭',
    seconds: 1500,
    kind: TaskIcon.rice,
    categoryId: 2,
  ),
  TimerPreset(
    id: 6,
    name: '煲汤',
    seconds: 2700,
    kind: TaskIcon.soup,
    categoryId: 2,
  ),
  TimerPreset(
    id: 7,
    name: '专注工作',
    seconds: 1500,
    kind: TaskIcon.work,
    categoryId: 6,
  ),
  TimerPreset(
    id: 8,
    name: '平板支撑',
    seconds: 60,
    kind: TaskIcon.fitness,
    categoryId: 4,
  ),
  TimerPreset(
    id: 9,
    name: '跑步训练',
    seconds: 1800,
    kind: TaskIcon.running,
    categoryId: 5,
  ),
];

enum TimerStatus { running, paused, completed }

/// Editing a preset never changes an already running timer.
class ActiveTimer {
  const ActiveTimer({
    required this.preset,
    required this.status,
    required this.remainingMilliseconds,
    this.deadline,
  });

  final TimerPreset preset;
  final TimerStatus status;
  final int remainingMilliseconds;
  final DateTime? deadline;
  int get id => preset.id;

  int remainingAt(DateTime now) {
    if (status == TimerStatus.completed) return 0;
    if (status == TimerStatus.paused) return remainingMilliseconds;
    return deadline!.difference(now).inMilliseconds.clamp(0, 359999000);
  }

  int secondsAt(DateTime now) => (remainingAt(now) / 1000).ceil();

  Map<String, dynamic> toJson() => {
    'preset': preset.toJson(),
    'status': status.name,
    'remainingMilliseconds': remainingMilliseconds,
    'deadline': deadline?.millisecondsSinceEpoch,
  };

  factory ActiveTimer.fromJson(
    Map<String, dynamic> json, {
    bool legacy = false,
  }) {
    final status = TimerStatus.values.byName(json['status'] as String);
    final deadline = json['deadline'] as int?;
    final remaining = json['remainingMilliseconds'] as int;
    if ((status == TimerStatus.running && deadline == null) ||
        remaining < 0 ||
        remaining > 359999000 ||
        (status == TimerStatus.paused && remaining == 0)) {
      throw const FormatException('Invalid timer state');
    }
    return ActiveTimer(
      preset: TimerPreset.fromJson(
        json['preset'] as Map<String, dynamic>,
        legacy: legacy,
      ),
      status: status,
      remainingMilliseconds: remaining,
      deadline: deadline == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(deadline),
    );
  }
}

String clockText(int seconds) {
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  final remainder = seconds % 60;
  return [
    if (hours > 0) hours.toString().padLeft(2, '0'),
    minutes.toString().padLeft(2, '0'),
    remainder.toString().padLeft(2, '0'),
  ].join(':');
}

String durationText(int seconds) {
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  final remainder = seconds % 60;
  return [
    if (hours > 0) '$hours小时',
    if (minutes > 0) '$minutes分',
    if (remainder > 0) '$remainder秒',
    if (seconds == 0) '0秒',
  ].join();
}
