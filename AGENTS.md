# 项目快速上手

## 产品定位

这是中文 Flutter 通用计时管理应用，涵盖健身、运动、工作、学习、生活、烹饪等场景。用户可以自定义任务和分类；内置内容仅是首次安装的示例，不是固定上限。不要重新把任务分类绑定到图标或厨房场景。

当前仅配置 Android。应用名为「计时管理」，Dart 包名仍是 `flutterproject`，Android applicationId 为 `com.example.flutterproject`，入口组件为 `TimerManagerApp`。

## 优先阅读

1. `README.md`：使用方式、构建、功能范围和平台限制。
2. `lib/src/timer_models.dart`：`TimerPreset`、`TimerCategory`、`TaskIcon`、`ActiveTimer` 和 JSON。
3. `lib/src/timer_controller.dart`：任务/分类 CRUD、计时状态、迁移和串行保存。
4. `lib/src/home_page.dart`：主界面、分类筛选、活动计时卡片、删除任务与撤销。
5. `lib/src/preset_editor.dart`、`category_manager.dart`：任务表单和分类管理；任务表单内可直接新建分类。
6. `lib/src/timer_platform.dart`、`android/app/src/main/kotlin/com/example/flutterproject/`：MethodChannel 与 Android 闹钟、通知、SharedPreferences。

`lib/src/task_art.dart` 使用 Material 图标和本地 Canvas 插画，不依赖网络图片。`theme.dart` 提供 `TimerColors` 和 `timerTheme`。

## 数据与行为约束

- `TimerPreset.categoryId` 是分类的稳定整数 ID，`null` 表示「未分类」。`TaskIcon` 只决定视觉效果，改变图标不改变分类。
- 分类可以新增、重命名、删除；名称去首尾空白、限制 1–20 字符、忽略大小写去重。「全部」「未分类」是保留名称，不作为用户分类记录保存。
- 重命名保留 ID。删除分类将其任务移到「未分类」，不能删除任务或中断计时。首页筛选值 `-1` 为全部，`0` 为未分类，正数为分类 ID；这些筛选哨兵不能写入任务的 `categoryId`。
- 任务名称限制 1–20 字符，时长为 1–359999 秒。同一任务最多一个活动计时；点击运行中的任务不会重复启动，点击暂停任务会继续。
- `ActiveTimer` 持有不可变任务快照。修改/删除任务、修改/删除分类都不能改动当前计时的名称、时长、状态和 deadline。活动快照允许引用已删除的分类。
- 运行时以绝对 deadline 计算剩余时间；250ms ticker 仅刷新界面。暂停保留毫秒精度，重置恢复快照原时长并暂停。
- 保存采用串行快照队列 `_pendingSave`，避免快速操作让旧状态覆盖新状态；测试需要保存完成时等待 `controller.saved`。
- 本地 JSON 当前为 **version 2**：`version`、`nextId`、`nextCategoryId`、`categories`、`presets`、`timers`。任务仍保存 `kind` 枚举名称，新增 `categoryId`。
- version 1 必须兼容：仅迁移原有记录，根据旧 `kind` 映射日常/烹饪/饮品三个分类，然后保存为 version 2。保持任务 ID、时长、暂停剩余毫秒和 deadline；不为升级用户追加默认任务，空任务库仍为空。
- 首次安装才使用 `defaultPresets` 和 `defaultCategories`。调整默认内容时同步检查 `_nextId`/`_nextCategoryId`；加载时也会校正它们，避免复用任务及活动快照中的 ID。
- 首次打开即串行保存初始状态，用本地状态是否存在区分首次访问；欢迎卡片只在首次访问中显示，开始任务后隐藏。已有 version 1/2 用户不再显示欢迎卡片。
- `kitchen_timer/platform`、SharedPreferences 的 `kitchen_timer`/`kitchen_timer_permissions`、通知 channel `kitchen_timer_finished` 是兼容性标识。不要因产品改名而直接改动，否则可能丢失已有数据或通知设置。
- Android 从 `timers` 读取任务 ID、名称、status 和 deadline，保存状态也同步系统闹钟。暂停/重置/取消需要撤销相应闹钟，完成通知按本次 deadline 去重。
- 全局结束铃声通过 `TimerRingtoneSettings` 调用系统铃声选择器，独立保存到原 SharedPreferences 的 `ringtone_uri` / `ringtone_title`，不写入任务 JSON。缺省为内置铃声，系统默认项保留动态 URI；取消选择不改设置。不能改动手机默认铃声或已有通知频道。
- `TimerRingingService` 用闹钟音量播放所选铃声，读取或解码失败回退到内置铃声，每次完成最多 15 秒；多个计时共享播放器。设置更改不切换当前播放器。重置/取消/完成必须停止对应 deadline 的响铃，编辑/删除任务或分类不影响活动响铃。保留用户通知静音设置；重启接收器不得直接启动媒体播放服务。

## 开发与验证

已验证工具链：Flutter **3.47.2** / Dart **3.13.2**。常规命令：

```sh
flutter pub get
dart format lib test
flutter analyze
flutter test
flutter build apk --debug
```

此 Windows 工作区的 Flutter 在 `D:/Dev/flutter/bin/flutter.bat`，Dart 在同目录 `dart.bat`；未配置 PATH 时用 PowerShell `&` 调用绝对路径。Android Studio 的 JDK 在 `D:/Android/Android Studio/jbr`，直接运行 Gradle 前可为当前进程设置 `JAVA_HOME`。这些是本机路径，不应硬编码进应用或共享构建配置。

修改 Android 原生代码后还应在 `android` 目录运行 `./gradlew :app:lintDebug`（Windows：`./gradlew.bat :app:lintDebug`）。Gradle wrapper / local.properties 由 Flutter 工具生成，首次克隆先执行 Flutter 构建。

原生提醒回归测试运行 `./gradlew :app:testDebugUnitTest`（Windows 使用 `./gradlew.bat`），测试文件在 `android/app/src/test/kotlin/com/example/flutterproject/`。

Windows 下若 lint 报 `PropertyEscape`，检查本机 `android/local.properties` 的盘符冒号和反斜线是否正确转义（例如 `D\:\\Dev\\flutter`）；该文件应继续被 Git 忽略。

测试入口：

- `test/timer_controller_test.dart`：计时、暂停恢复、持久化、任务/分类隔离、分类校验和删除、version 1 迁移、错误处理。
- `test/widget_test.dart`：任务表单、创建分类、换分类、分类管理、筛选、320px 屏幕与放大字体。
- `test/support/fake_timer_platform.dart`：无 Android 依赖的平台替身；通过注入 `now` 控制时间，避免真实等待。注入的 controller 由测试释放。

涉及持久化或数据模型时补充真实的迁移/恢复测试；涉及交互时验证窄屏、长分类名和系统字体放大。不要仅为文案变化增加重复测试。

## 交付

源码仓库：`https://github.com/Ghpt6/timer-manager.git`，主分支 `main`。不要提交 `build/`、`.dart_tool/`、本机 SDK 路径、签名文件或凭据。

当前版本为 `1.2.0+4005`。后续覆盖安装递增 `pubspec.yaml` 的构建号；调试包和分 ABI 体验包共用版本号，`android/gradle.properties` 已关闭 ABI 版本偏移。release 目前使用调试签名，正式商店发布需要另行配置签名。

GitHub Actions 配置为 `.github/workflows/android.yml`：main/PR 自动检查并构建调试包；推送 `v*` 标签或在 main 手动勾选 `publish` 会测试、构建并发布 GitHub Release。发布要求 `ANDROID_DEBUG_KEYSTORE_BASE64` Secret，必须复用之前发布 APK 的调试签名，不得在 CI 中临时生成替代签名后发布。普通 CI 不使用此 Secret，其调试包不能用于覆盖旧版。版本校验脚本为 `.github/scripts/release_metadata.py`，标签与版本名一致，构建号高于所有旧版本标签；使用原生测试前先由 Flutter 构建生成未跟踪的 Gradle wrapper。详情见 README 的自动发布说明。
