import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme.dart';
import 'timer_platform.dart';

Future<void> showRingtoneSettings(
  BuildContext context,
  TimerPlatform platform,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  constraints: const BoxConstraints(maxWidth: 600),
  builder: (_) => _RingtoneSettings(platform: platform),
);

class _RingtoneSettings extends StatefulWidget {
  const _RingtoneSettings({required this.platform});
  final TimerPlatform platform;

  @override
  State<_RingtoneSettings> createState() => _RingtoneSettingsState();
}

class _RingtoneSettingsState extends State<_RingtoneSettings> {
  TimerRingtone? _ringtone;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() => _run(widget.platform.readRingtone);

  Future<void> _run(Future<TimerRingtone?> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final selection = await action();
      if (!mounted) return;
      setState(() {
        if (selection != null) _ringtone = selection;
      });
    } on PlatformException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message ?? '无法设置铃声，请重试。');
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = '无法读取或设置铃声，请重试。');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '计时结束铃声',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                key: const ValueKey('close-ringtone-settings'),
                onPressed: () => Navigator.pop(context),
                tooltip: '关闭',
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text('所有任务共用，下次响铃时生效。已经响起的铃声会保持到本次结束。'),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: TimerColors.cream,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('当前铃声', style: TextStyle(color: TimerColors.muted)),
                const SizedBox(height: 6),
                Text(
                  _ringtone?.title ?? '正在读取…',
                  key: const ValueKey('current-ringtone'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (_busy) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            if (_ringtone == null)
              TextButton(
                onPressed: _busy ? null : _load,
                child: const Text('重新读取'),
              ),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            key: const ValueKey('pick-ringtone'),
            onPressed: _busy ? null : () => _run(widget.platform.pickRingtone),
            icon: const Icon(Icons.music_note_rounded),
            label: const Text('选择系统铃声'),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            key: const ValueKey('reset-ringtone'),
            onPressed: _busy || _ringtone == null || _ringtone!.isBuiltIn
                ? null
                : () => _run(widget.platform.resetRingtone),
            child: const Text('恢复内置铃声'),
          ),
          const SizedBox(height: 16),
          const Text(
            '可在系统选择器中试听，也可选择跟随系统默认闹钟铃声。\n\n到时使用闹钟音量，最长响铃 15 秒；若所选铃声无法播放，将使用内置铃声。',
            style: TextStyle(color: TimerColors.muted, height: 1.5),
          ),
        ],
      ),
    ),
  );
}
