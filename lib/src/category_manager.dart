import 'package:flutter/material.dart';

import 'theme.dart';
import 'timer_controller.dart';
import 'timer_models.dart';

Future<TimerCategory?> showCategoryEditor(
  BuildContext context,
  TimerController controller, {
  TimerCategory? category,
}) => showDialog<TimerCategory>(
  context: context,
  builder: (_) => _CategoryEditor(controller: controller, category: category),
);

Future<void> showCategoryManager(
  BuildContext context,
  TimerController controller,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  constraints: const BoxConstraints(maxWidth: 600),
  builder: (_) => _CategoryManager(controller: controller),
);

class _CategoryEditor extends StatefulWidget {
  const _CategoryEditor({required this.controller, this.category});
  final TimerController controller;
  final TimerCategory? category;

  @override
  State<_CategoryEditor> createState() => _CategoryEditorState();
}

class _CategoryEditorState extends State<_CategoryEditor> {
  late final _name = TextEditingController(text: widget.category?.name ?? '');
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    try {
      final category = widget.controller.saveCategory(
        id: widget.category?.id,
        name: _name.text,
      );
      Navigator.pop(context, category);
    } on ArgumentError catch (error) {
      setState(() => _error = error.message.toString());
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.category == null ? '新建分类' : '重命名分类'),
    content: TextField(
      key: const ValueKey('category-name'),
      controller: _name,
      autofocus: true,
      maxLength: 20,
      textInputAction: TextInputAction.done,
      decoration: InputDecoration(
        labelText: '分类名称',
        hintText: '例如：健身、工作、学习',
        errorText: _error,
        errorMaxLines: 3,
      ),
      onSubmitted: (_) => _save(),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        key: const ValueKey('save-category'),
        onPressed: _save,
        child: const Text('保存'),
      ),
    ],
  );
}

class _CategoryManager extends StatelessWidget {
  const _CategoryManager({required this.controller});
  final TimerController controller;

  Future<void> _delete(BuildContext context, TimerCategory category) async {
    final count = controller.presets
        .where((e) => e.categoryId == category.id)
        .length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('删除「${category.name}」？'),
        content: Text('该分类下的 $count 个任务会移到「未分类」，正在进行的计时不受影响。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            key: const ValueKey('confirm-delete-category'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除分类'),
          ),
        ],
      ),
    );
    if (confirmed == true) controller.deleteCategory(category.id);
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .75,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '管理分类',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  key: const ValueKey('close-categories'),
                  tooltip: '关闭',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const Text(
              '按自己的生活方式整理任务。',
              style: TextStyle(color: TimerColors.muted),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: AnimatedBuilder(
                animation: controller,
                builder: (context, _) => ListView(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.inbox_outlined),
                      title: const Text('未分类'),
                      subtitle: Text(
                        '${controller.presets.where((e) => e.categoryId == null).length} 个任务 · 默认收纳',
                      ),
                    ),
                    for (final category in controller.categories)
                      ListTile(
                        key: ValueKey('category-row-${category.id}'),
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          category.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${controller.presets.where((e) => e.categoryId == category.id).length} 个任务',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              key: ValueKey('rename-category-${category.id}'),
                              tooltip: '重命名${category.name}',
                              onPressed: () => showCategoryEditor(
                                context,
                                controller,
                                category: category,
                              ),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            IconButton(
                              key: ValueKey('delete-category-${category.id}'),
                              tooltip: '删除${category.name}',
                              onPressed: () => _delete(context, category),
                              icon: const Icon(Icons.delete_outline_rounded),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const ValueKey('add-category'),
                onPressed: () => showCategoryEditor(context, controller),
                icon: const Icon(Icons.add_rounded),
                label: const Text('新建分类'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
