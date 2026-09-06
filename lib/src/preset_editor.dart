import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'category_manager.dart';
import 'task_art.dart';
import 'theme.dart';
import 'timer_controller.dart';
import 'timer_models.dart';

Future<TimerPreset?> showPresetEditor(
  BuildContext context,
  TimerController controller, {
  TimerPreset? preset,
  int? initialCategoryId,
}) => showModalBottomSheet<TimerPreset>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: Colors.white,
  constraints: const BoxConstraints(maxWidth: 600),
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
  ),
  builder: (_) => _PresetEditor(
    controller: controller,
    preset: preset,
    initialCategoryId: initialCategoryId,
  ),
);

class _PresetEditor extends StatefulWidget {
  const _PresetEditor({
    required this.controller,
    this.preset,
    this.initialCategoryId,
  });
  final TimerController controller;
  final TimerPreset? preset;
  final int? initialCategoryId;

  @override
  State<_PresetEditor> createState() => _PresetEditorState();
}

class _PresetEditorState extends State<_PresetEditor> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.preset?.name ?? '');
  late final _hours = TextEditingController(
    text: ((widget.preset?.seconds ?? 300) ~/ 3600).toString().padLeft(2, '0'),
  );
  late final _minutes = TextEditingController(
    text: (((widget.preset?.seconds ?? 300) % 3600) ~/ 60).toString().padLeft(
      2,
      '0',
    ),
  );
  late final _seconds = TextEditingController(
    text: ((widget.preset?.seconds ?? 300) % 60).toString().padLeft(2, '0'),
  );
  late TaskIcon _kind = widget.preset?.kind ?? TaskIcon.timer;
  late int? _categoryId = widget.preset != null
      ? widget.preset!.categoryId
      : widget.initialCategoryId;
  String? _durationError;
  String? _saveError;

  @override
  void dispose() {
    for (final controller in [_name, _hours, _minutes, _seconds]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _save() {
    final valid = _formKey.currentState!.validate();
    final seconds =
        (int.tryParse(_hours.text) ?? 0) * 3600 +
        (int.tryParse(_minutes.text) ?? 0) * 60 +
        (int.tryParse(_seconds.text) ?? 0);
    setState(() => _durationError = seconds == 0 ? '计时时长至少为 1 秒' : null);
    if (!valid || seconds == 0) return;
    try {
      final preset = widget.controller.savePreset(
        id: widget.preset?.id,
        name: _name.text,
        seconds: seconds,
        kind: _kind,
        categoryId: _categoryId,
      );
      Navigator.pop(context, preset);
    } on ArgumentError catch (error) {
      setState(() => _saveError = error.message.toString());
    }
  }

  Future<void> _addCategory() async {
    final category = await showCategoryEditor(context, widget.controller);
    if (mounted && category != null) setState(() => _categoryId = category.id);
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: TimerColors.line,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.preset == null ? '添加任务' : '编辑任务',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    tooltip: '关闭',
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const Text(
                '健身、运动、工作，按你的节奏计时。',
                style: TextStyle(color: TimerColors.muted),
              ),
              const SizedBox(height: 24),
              TextFormField(
                key: const ValueKey('preset-name'),
                controller: _name,
                maxLength: 20,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: '任务名称',
                  hintText: '例如：平板支撑、专注工作',
                  counterText: '',
                ),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? '给计时取个名字吧' : null,
              ),
              const SizedBox(height: 24),
              const Text('计时时长', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _timeField(_hours, '时', 99, 'duration-hours'),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(8, 14, 8, 0),
                    child: Text(':', style: TextStyle(fontSize: 26)),
                  ),
                  _timeField(_minutes, '分', 59, 'duration-minutes'),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(8, 14, 8, 0),
                    child: Text(':', style: TextStyle(fontSize: 26)),
                  ),
                  _timeField(_seconds, '秒', 59, 'duration-seconds'),
                ],
              ),
              if (_durationError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _durationError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      '所属分类',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  TextButton.icon(
                    key: const ValueKey('create-category-in-editor'),
                    onPressed: _addCategory,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('新建分类'),
                  ),
                ],
              ),
              DropdownButtonFormField<int>(
                key: ValueKey('preset-category-${_categoryId ?? 0}'),
                initialValue: _categoryId ?? 0,
                isExpanded: true,
                decoration: const InputDecoration(labelText: '分类'),
                items: [
                  const DropdownMenuItem(value: 0, child: Text('未分类')),
                  for (final category in widget.controller.categories)
                    DropdownMenuItem(
                      value: category.id,
                      child: Text(
                        category.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (value) =>
                    setState(() => _categoryId = value == 0 ? null : value),
              ),
              const SizedBox(height: 20),
              const Text('选择图标', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final kind in TaskIcon.values)
                      Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: Semantics(
                          button: true,
                          selected: _kind == kind,
                          label: '${kind.label}图标',
                          child: InkWell(
                            key: ValueKey('icon-${kind.name}'),
                            onTap: () => setState(() => _kind = kind),
                            borderRadius: BorderRadius.circular(16),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              width: 72,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: _kind == kind
                                    ? taskTint(kind)
                                    : TimerColors.background,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: _kind == kind
                                      ? TimerColors.orange
                                      : Colors.transparent,
                                  width: 1.5,
                                ),
                              ),
                              child: Column(
                                children: [
                                  TaskArt(kind: kind, size: 42),
                                  Text(
                                    kind.label,
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '左右滑动选择图标，图标不影响任务分类。',
                style: TextStyle(fontSize: 12, color: TimerColors.muted),
              ),
              if (widget.preset != null &&
                  widget.controller.timerFor(widget.preset!.id) != null)
                const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: Text(
                    '修改将在下次计时生效，当前计时保持原样。',
                    style: TextStyle(fontSize: 12, color: TimerColors.muted),
                  ),
                ),
              const SizedBox(height: 24),
              if (_saveError != null)
                Text(
                  _saveError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const ValueKey('save-preset'),
                  onPressed: _save,
                  child: Text(widget.preset == null ? '保存计时' : '保存修改'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _timeField(
    TextEditingController controller,
    String unit,
    int max,
    String key,
  ) => Expanded(
    child: Column(
      children: [
        TextFormField(
          key: ValueKey(key),
          controller: controller,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(2),
          ],
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
          decoration: const InputDecoration(
            contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 4),
          ),
          onTap: () => controller.selection = TextSelection(
            baseOffset: 0,
            extentOffset: controller.text.length,
          ),
          validator: (value) =>
              (int.tryParse(value ?? '') ?? 0) > max ? '0–$max' : null,
        ),
        const SizedBox(height: 6),
        Text(
          unit,
          style: const TextStyle(color: TimerColors.muted, fontSize: 12),
        ),
      ],
    ),
  );
}
