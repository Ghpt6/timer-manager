# 计时管理 · Timer Manager

一个中文 Flutter 通用计时管理应用，适用于健身、运动、工作、学习、烹饪和日常生活。轻点任务卡片即可开始倒计时，任务与分类都可以自由管理。![alt text](images/app.png)

## 功能

- **自定义任务**：添加、编辑、删除任务；自由设置名称、图标和时长，支持 1 秒至 99 小时 59 分 59 秒。删除任务后可撤销。
- **自定义分类**：新建、重命名、删除分类；为任意任务选择所属分类，图标与分类互不绑定。删除分类后，任务移到「未分类」。
- **快速整理**：首页按分类筛选，卡片显示所属分类；在某个分类下添加任务时自动选中该分类，也可以在任务表单内直接新建分类。
- **多任务计时**：多个任务同时运行，支持暂停、继续、重置、取消和完成后再来一次。同一任务不会重复启动；重置恢复原时长并暂停。
- **数据持久化**：任务、分类及计时状态自动保存在本地。重新打开应用会恢复剩余时间或显示已完成；编辑任务或分类不影响正在进行的计时。
- **Android 提醒**：到时通知、独立闹钟铃声和振动，支持后台、锁屏、进程退出及设备重启后的提醒恢复。铃声最长 15 秒，点击通知中的「停止铃声」或应用内「完成」可提前停止。
- **结束铃声设置**：首页右上角的音符入口可选择并试听手机系统闹钟铃声，也可跟随系统默认闹钟铃声或恢复内置铃声。所有任务共用设置，重新打开后保留。
- **通用视觉**：提供通用、健身、运动、工作、学习、冥想及烹饪图标，保留暖色卡片和本地矢量插画，适配窄屏与放大字体。

首次安装提供 9 个示例任务（包括烧水、煮蛋、专注工作、平板支撑、跑步训练）和 6 个可编辑分类。它们仅是起点，用户可继续添加自己的任务和分类。

「不慌不忙，刚刚好」欢迎卡片仅在首次打开时显示，开始计时后立即隐藏；再次打开或覆盖升级后不再显示。删除任务后的撤销提示会在 4 秒后自动关闭。

## 使用

1. 点击底部「添加任务」，输入名称、时长，选择分类与图标，保存后轻点卡片开始计时。
2. 点击卡片右上角「⋯」→「编辑」，可以修改任务，也可以将它移到其他分类或「未分类」。
3. 点击「管理分类」新建、重命名或删除分类；任务表单的「新建分类」入口会在创建后自动选中新分类。
4. 第一次开始计时时允许通知，并确保系统**闹钟音量**大于零；若通知、精确提醒或通知声音未开启，可通过活动计时区的提示进入对应系统设置。
5. 点击首页右上角音符 →「选择系统铃声」，在手机提供的选择器中试听并确认。返回或取消不会更改原选择；「恢复内置铃声」可切回原有声音。更改后在下次开始响铃时使用，已在播放的铃声不会中途切换。

分类和任务名称最多 20 个字符。分类名称不能重复，「全部」「未分类」为保留名称。

## 运行与构建

当前配置 **Android**，最低 Android 7.0（API 24）。已验证 Flutter **3.47.2** / Dart **3.13.2**，需要可用的 Android SDK 和 JDK。Gradle 工具链配置见 `android/gradle/gradle-daemon-jvm.properties`。

```sh
git clone https://github.com/Ghpt6/timer-manager.git
cd timer-manager
flutter pub get
flutter run
```

本机 Flutter SDK 位于 `D:/Dev/flutter`。未配置 PATH 时可在 PowerShell 中使用 `& D:/Dev/flutter/bin/flutter.bat run`。

```sh
dart format lib test
flutter analyze
flutter test
flutter build apk --debug
```

调试包：`build/app/outputs/flutter-apk/app-debug.apk`。较小的分架构体验包：

```sh
flutter build apk --release --split-per-abi
```

通常 Android 真机使用 `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`。当前 release 配置沿用调试签名，商店发布前需配置正式签名。

版本为 **1.2.0+4005**，可以保留原应用数据覆盖安装。调试和分架构包共用 `pubspec.yaml` 的构建号，已关闭 ABI 版本号偏移；后续更新递增 `+` 后的构建号。

修改 Android 原生代码后，在 `android` 目录运行 `./gradlew :app:lintDebug`（Windows 用 `./gradlew.bat`）。首次克隆先执行 Flutter 构建以生成 wrapper 和 local.properties；直接调用 Gradle 前需配置 `JAVA_HOME`。

原生提醒回归测试：在 `android` 目录运行 `./gradlew :app:testDebugUnitTest`，使用 Robolectric 检查提醒去重、过期广播、静音设置、响铃停止和重启恢复。

## 代码导航

| 文件 | 职责 |
| --- | --- |
| `lib/main.dart` | 应用入口、主题与 controller 生命周期 |
| `lib/src/timer_models.dart` | 任务、分类、图标和活动计时模型 |
| `lib/src/timer_controller.dart` | 状态变更、计时、持久化与数据迁移 |
| `lib/src/home_page.dart` | 首页、分类筛选、活动计时与任务卡片 |
| `lib/src/preset_editor.dart` | 任务表单、选择分类及图标 |
| `lib/src/category_manager.dart` | 分类创建、重命名和删除 |
| `lib/src/ringtone_settings.dart` | 全局结束铃声设置与错误提示 |
| `lib/src/task_art.dart` | 本地矢量插画与通用图标 |
| `lib/src/timer_platform.dart` | Flutter / Android MethodChannel |
| `android/app/src/main/kotlin/com/example/flutterproject/TimerAlarms.kt` | 本地存储、系统闹钟、通知与重启恢复 |
| `android/app/src/main/kotlin/com/example/flutterproject/TimerRingtoneSettings.kt` | 系统铃声选择器、URI 和名称存储、恢复内置铃声 |
| `android/app/src/main/kotlin/com/example/flutterproject/TimerRingingService.kt` | 到时播放所选铃声、失败回退、闹钟音频焦点、自动停止与停止按钮 |
| `AGENTS.md` | 面向后续开发者与 AI 编程助手的项目约束和验证指南 |

测试覆盖计时精度与恢复、任务快照隔离、自定义分类持久化、分类删除与换分类、旧数据迁移、表单校验及 320px 窄屏和放大字体。

## 升级与平台说明

本地数据格式已从 version 1 升至 version 2，新增独立的分类记录和任务 `categoryId`。旧版用户原有任务、名称、时长、分类归属和正在运行的计时会保留；升级时不会额外插入示例任务，已清空的任务库也保持为空。删除分类不改变活动计时的快照或结束时间。

Android applicationId、MethodChannel 和存储标识沿用旧值，以支持覆盖安装和读取旧数据。倒计时依据绝对结束时间计算；Android 用 `AlarmManager.setAlarmClock` 安排精确提醒，并按每次运行的结束时间去重。未获精确提醒权限时会降级并提示用户。通知未开启时无法发送后台通知；系统「强行停止」会取消闹钟，重新打开后恢复安排。手动修改系统时间会影响剩余时间。

到时由短时前台服务播放所选铃声，使用系统闹钟音量，避免仅依赖通知铃声。多个任务同时完成共用一个播放器，各自最多响铃 15 秒；重置、取消或完成对应计时会结束该次响铃。已有通知频道和用户静音设置保留，勿扰模式与闹钟音量仍由系统控制。若系统拒绝启动服务，则退回系统通知（声音由系统通知设置控制）；设备重启时已过期的计时仅补发通知，未过期的计时重新安排闹钟。

铃声默认沿用内置声音，新旧安装均可主动更换。全局选择保存在原 SharedPreferences 的独立 `ringtone_uri` / `ringtone_title` 键中，不改变 version 2 任务 JSON，不改动系统默认铃声或通知频道。系统默认项保存为动态 URI；所选音频被删除、访问权限失效或解码失败时自动回退到内置铃声。使用系统铃声无需申请扫描音频库的权限。系统选择器的样式和可用铃声由手机决定，缺少选择器的设备会显示提示。

实现参考：[AOSP DeskClock 的铃声选择与计时铃声存储](https://android.googlesource.com/platform/packages/apps/DeskClock/+/refs/heads/main/src/com/android/deskclock/ringtone/RingtonePickerActivity.kt)、[UltimateRingtonePicker 的系统铃声和试听设计](https://github.com/DeweyReed/UltimateRingtonePicker)、[Android RingtoneManager 官方文档](https://developer.android.com/reference/android/media/RingtoneManager)。当前通过已有 MethodChannel 调用系统 `ACTION_RINGTONE_PICKER`，无需引入额外铃声库。

REDMI / HyperOS 上如仍无声，请先按应用提示检查「计时完成提醒」的声音开关和闹钟音量，并确认勿扰模式允许闹钟。若仅后台提醒延迟，再检查应用的自启动及电池限制。本版本没有在 REDMI Turbo 5 Max 真机上验证。

当前没有 iOS 工程或对应的平台提醒实现。
