part of 'today_screen.dart';

// The draggable task list and the task card it renders.

class _DraggableTaskList extends ConsumerStatefulWidget {
  final List<Task> tasks;
  const _DraggableTaskList({required this.tasks});

  @override
  ConsumerState<_DraggableTaskList> createState() => _DraggableTaskListState();
}

class _DraggableTaskListState extends ConsumerState<_DraggableTaskList> {
  String? _draggingId;
  String? _hoveredId;
  DropZone _hoverZone = DropZone.before;
  final _rowCtxs = <String, BuildContext>{};

  // Subtasks are capped at one level, so a row only accepts children when it is
  // top-level and the dragged task has no children of its own
  bool _canNestInto(Task row, String draggedId) {
    if (row.parentTaskId != null) return false;
    if (row.id == draggedId) return false;
    return !ref.read(tasksProvider).any((t) => t.parentTaskId == draggedId);
  }

  void _onAccept(String draggedId, Task row, List<Task> siblings, int index) {
    final notifier = ref.read(tasksProvider.notifier);
    switch (_hoverZone) {
      case DropZone.before:
        final prev = index > 0 ? siblings[index - 1].sortOrder : null;
        notifier.reorderTask(
            draggedId, row.parentTaskId, orderBetween(prev, row.sortOrder));
      case DropZone.after:
        final next =
            index < siblings.length - 1 ? siblings[index + 1].sortOrder : null;
        notifier.reorderTask(
            draggedId, row.parentTaskId, orderBetween(row.sortOrder, next));
      case DropZone.into:
        final childOrders = ref
            .read(tasksProvider)
            .where((t) => t.parentTaskId == row.id)
            .map((t) => t.sortOrder);
        notifier.reorderTask(draggedId, row.id, orderAfterLast(childOrders));
    }
    setState(() {
      _draggingId = null;
      _hoveredId = null;
    });
  }

  Widget _buildRow(Task task, int depth, List<Task> siblings, int index) {
    final isHovered = _hoveredId == task.id;
    final tile = _TaskTile(task: task, depth: depth);

    return DragTarget<String>(
      onWillAcceptWithDetails: (details) => details.data != task.id,
      onMove: (details) {
        final storedCtx = _rowCtxs[task.id];
        if (storedCtx == null) return;
        final box = storedCtx.findRenderObject() as RenderBox?;
        if (box == null) return;
        // details.offset is the pointer because the Draggable below uses
        // pointerDragAnchorStrategy
        final zone = dropZoneFor(box, details.offset,
            canNest: _canNestInto(task, details.data));
        if (_hoveredId != task.id || _hoverZone != zone) {
          setState(() {
            _hoveredId = task.id;
            _hoverZone = zone;
          });
        }
      },
      onLeave: (_) {
        if (_hoveredId == task.id) setState(() => _hoveredId = null);
      },
      onAcceptWithDetails: (details) => _onAccept(details.data, task, siblings, index),
      builder: (dragCtx, _, _) {
        _rowCtxs[task.id] = dragCtx;
        final draggable = kIsWeb
            ? Draggable<String>(
                data: task.id,
                dragAnchorStrategy: pointerDragAnchorStrategy,
                feedback: _dragFeedback(task),
                childWhenDragging: Opacity(opacity: 0.3, child: tile),
                onDragStarted: () => setState(() => _draggingId = task.id),
                onDragEnd: (_) => setState(() {
                  _draggingId = null;
                  _hoveredId = null;
                }),
                child: tile,
              )
            : LongPressDraggable<String>(
                data: task.id,
                dragAnchorStrategy: pointerDragAnchorStrategy,
                feedback: _dragFeedback(task),
                childWhenDragging: Opacity(opacity: 0.3, child: tile),
                onDragStarted: () => setState(() => _draggingId = task.id),
                onDragEnd: (_) => setState(() {
                  _draggingId = null;
                  _hoveredId = null;
                }),
                child: tile,
              );

        // Stack, not a border on the Container: a border adds layout height
        // and makes the row jump while hovering
        return Stack(
          children: [
            ColoredBox(
              color: isHovered && _hoverZone == DropZone.into
                  ? AppColors.primaryLight
                  : Colors.transparent,
              child: draggable,
            ),
            if (isHovered && _hoverZone == DropZone.before)
              const Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: ColoredBox(
                      color: AppColors.primary, child: SizedBox(height: 2))),
            if (isHovered && _hoverZone == DropZone.after)
              const Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: ColoredBox(
                      color: AppColors.primary, child: SizedBox(height: 2))),
          ],
        );
      },
    );
  }

  Widget _dragFeedback(Task task) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          child: Text(task.title, overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tasks = widget.tasks;
    final topLevel = tasks.where((t) => t.parentTaskId == null).toList();
    final rows = <Widget>[];

    for (var i = 0; i < topLevel.length; i++) {
      final parent = topLevel[i];
      if (rows.isNotEmpty) {
        rows.add(const Divider(height: 1, indent: _taskTitleIndent));
      }
      rows.add(_buildRow(parent, 0, topLevel, i));

      final children = tasks.where((t) => t.parentTaskId == parent.id).toList();
      for (var j = 0; j < children.length; j++) {
        rows.add(const Divider(height: 1, indent: _taskTitleIndent));
        rows.add(_buildRow(children[j], 1, children, j));
      }
    }

    // Tail drop zone: promotes a dragged subtask back to top level
    if (_draggingId != null && topLevel.isNotEmpty) {
      rows.add(
        DragTarget<String>(
          onAcceptWithDetails: (details) {
            final lastOrder = topLevel.last.sortOrder;
            ref.read(tasksProvider.notifier).reorderTask(details.data, null, lastOrder + 1000);
            setState(() {
              _draggingId = null;
              _hoveredId = null;
            });
          },
          builder: (_, candidate, _) => Container(
            height: 40,
            alignment: Alignment.center,
            color: candidate.isNotEmpty ? AppColors.primaryLight : Colors.transparent,
            child: const Icon(Icons.vertical_align_bottom, size: 16, color: AppColors.textTertiary),
          ),
        ),
      );
    }

    return Column(children: rows);
  }
}

class _TaskTile extends ConsumerWidget {
  final Task task;
  final int depth;
  const _TaskTile({required this.task, this.depth = 0});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    final date = ref.watch(dateProvider);
    final effectiveDate = DateTime(date.year, date.month, date.day);
    final isCompleted = task.isCompletedOn(effectiveDate);
    final targets = ref.watch(semesterGoalsProvider);
    final goals = ref.watch(futureGoalsProvider);
    final cats = ref.watch(categoriesProvider);

    final linkedTarget = task.linkedTargetId != null
        ? targets.where((g) => g.id == task.linkedTargetId).firstOrNull
        : null;
    final linkedGoal = task.linkedGoalId != null
        ? goals.where((g) => g.id == task.linkedGoalId).firstOrNull
        : null;

    final targetColor = linkedTarget != null
        ? resolveCatColor(
            cats,
            linkedTarget.categories.isNotEmpty ? linkedTarget.categories.first : 'other',
          )
        : null;
    final goalColor = linkedGoal != null
        ? resolveCatColor(
            cats,
            linkedGoal.categories.isNotEmpty ? linkedGoal.categories.first : 'other',
          )
        : null;

    final hasSubtitle =
        task.content != null ||
        task.dueTime != null ||
        (task.recurrence != null && !task.recurrence!.isNone) ||
        linkedTarget != null ||
        linkedGoal != null;

    final tile = ListTile(
      contentPadding: EdgeInsets.fromLTRB(
        AppSpacing.sm + depth * 20.0,
        AppSpacing.xs,
        AppSpacing.sm,
        AppSpacing.xs,
      ),
      // Drop ListTile's 72dp two-line floor so the row hugs its content, and
      // center it so a link-less task doesn't sit high against the checkbox
      minTileHeight: 0,
      minLeadingWidth: 0,
      horizontalTitleGap: AppSpacing.sm,
      titleAlignment: ListTileTitleAlignment.center,
      leading: Checkbox(
        visualDensity: VisualDensity.compact,
        value: isCompleted,
        onChanged: (_) => ref.read(tasksProvider.notifier).toggleOnDate(task.id, effectiveDate),
      ),
      title: Text(
        task.title,
        style: TextStyle(
          decoration: isCompleted ? TextDecoration.lineThrough : null,
          color: isCompleted ? AppColors.textTertiary : null,
        ),
      ),
      subtitle: hasSubtitle
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (task.content != null)
                  Text(task.content!, style: Theme.of(context).textTheme.bodySmall),
                if (task.dueTime != null)
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 12, color: _dueColor(task.dueTime!)),
                      const SizedBox(width: AppSpacing.xs),
                      // Flexible + ellipsis: a bare Text in a Row gets unbounded
                      // width and overflows once the label grows
                      Flexible(
                        child: Text(
                          _formatDueTime(task.dueTime!),
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(color: _dueColor(task.dueTime!)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (task.recurrence != null && !task.recurrence!.isNone) ...[
                        const SizedBox(width: AppSpacing.xs),
                        const Icon(Icons.repeat, size: 12, color: AppColors.textSecondary),
                        const SizedBox(width: 2),
                        Flexible(
                          child: Text(
                            _recurrenceShort(task.recurrence!, s, task.createdAt),
                            style: Theme.of(
                              context,
                            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  )
                else if (task.recurrence != null && !task.recurrence!.isNone)
                  Row(
                    children: [
                      const Icon(Icons.repeat, size: 12, color: AppColors.textSecondary),
                      const SizedBox(width: 2),
                      Flexible(
                        child: Text(
                          _recurrenceShort(task.recurrence!, s, task.createdAt),
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                if (linkedTarget != null)
                  Text(
                    '$kArrow ${linkedTarget.title}',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.primary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (linkedGoal != null)
                  Text(
                    '⭐ ${linkedGoal.title}',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.primary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            )
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (task.priority > 1)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              margin: const EdgeInsets.only(right: AppSpacing.xs),
              decoration: BoxDecoration(
                color: task.priority == 3 ? AppColors.errorLight : AppColors.warningLight,
                borderRadius: BorderRadius.circular(AppRadius.xs),
              ),
              child: Text(
                task.priority == 3 ? s.priorityHigh : s.priorityMed,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: task.priority == 3 ? AppColors.error : AppColors.warning,
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            onPressed: () async {
              if (await confirmDelete(context, s)) {
                // Snapshot every removed task (parent + subtasks) so all of
                // them can be restored from the trash
                final removed = ref.read(tasksProvider.notifier).remove(task.id);
                final trash = ref.read(trashProvider.notifier);
                for (final t in removed) {
                  trash.addTask(t);
                }
              }
            },
          ),
        ],
      ),
      onTap: () => showTaskSheet(context, ref, existing: task),
    );

    // ListTile paints its ink splash on the nearest Material ancestor. The card
    // container and the drag-hover highlight are both DecoratedBoxes that would
    // otherwise sit in between and swallow the splash
    return Material(
      type: MaterialType.transparency,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _linkColorBar(targetColor, goalColor),
            Expanded(child: tile),
          ],
        ),
      ),
    );
  }
}

// Left edge color bar showing the category color of the task's linked
// target/goal; split top/bottom when both are linked with different colors.
Widget _linkColorBar(Color? top, Color? bottom) {
  const width = 6.0;
  // Always reserve the bar's width so linked and unlinked tiles stay aligned
  if (top == null && bottom == null) return const SizedBox(width: width);
  if (bottom == null) return Container(width: width, color: top);
  if (top == null) return Container(width: width, color: bottom);
  if (top.toARGB32() == bottom.toARGB32()) {
    return Container(width: width, color: top);
  }
  return SizedBox(
    width: width,
    child: Column(
      children: [
        Expanded(child: Container(color: top)),
        Expanded(child: Container(color: bottom)),
      ],
    ),
  );
}

// ─── Date+time picker (clock style) ──────────────────────────────────────────
