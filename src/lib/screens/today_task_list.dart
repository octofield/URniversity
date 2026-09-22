part of 'today_screen.dart';

// The draggable task list and the task card it renders.

class _DraggableTaskList extends ConsumerStatefulWidget {
  final List<Task> tasks;
  const _DraggableTaskList({required this.tasks});

  @override
  ConsumerState<_DraggableTaskList> createState() => _DraggableTaskListState();
}

class _DraggableTaskListState extends ConsumerState<_DraggableTaskList> {
  String? _hoveredId;
  DropZone _hoverZone = DropZone.before;
  final _rowCtxs = <String, BuildContext>{};

  void _onAccept(String draggedId, Task row, List<Task> siblings, int index) {
    final notifier = ref.read(tasksProvider.notifier);
    // The list is flat, so a drop only ever means "put it here"
    switch (_hoverZone) {
      case DropZone.before:
        final prev = index > 0 ? siblings[index - 1].sortOrder : null;
        notifier.reorderTask(draggedId, orderBetween(prev, row.sortOrder));
      case DropZone.after:
        final next =
            index < siblings.length - 1 ? siblings[index + 1].sortOrder : null;
        notifier.reorderTask(draggedId, orderBetween(row.sortOrder, next));
      case DropZone.into:
        // Nothing takes children any more; dropZoneFor is told so and never
        // reports this zone
        break;
    }
    setState(() => _hoveredId = null);
  }

  Widget _buildRow(Task task, List<Task> siblings, int index) {
    final isHovered = _hoveredId == task.id;
    // Dragging writes the manual order, which is invisible while the list is
    // sorted by something else — so it is switched off there rather than
    // quietly rearranging a list the user cannot see
    final canDrag = ref.watch(taskSortProvider) == TaskSort.manual;
    final sortMode = ref.watch(taskSortModeProvider);
    // While rearranging, the handle takes the delete button's place and is
    // the thing that drags, at once and without a long press
    final tile = _TaskTile(
      task: task,
      handle: sortMode && canDrag
          ? DragHandle<String>(
              data: task.id,
              feedback: _dragFeedback(task),
              onDragStarted: () {},
              onDragEnd: () => setState(() => _hoveredId = null),
            )
          : null,
    );
    if (!canDrag) return tile;

    return DragTarget<String>(
      onWillAcceptWithDetails: (details) => details.data != task.id,
      onMove: (details) {
        final storedCtx = _rowCtxs[task.id];
        if (storedCtx == null) return;
        final box = storedCtx.findRenderObject() as RenderBox?;
        if (box == null) return;
        // details.offset is the pointer because the Draggable below uses
        // pointerDragAnchorStrategy
        // Nothing nests any more, so a row is split into before/after only
        final zone = dropZoneFor(box, details.offset, canNest: false);
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
        final draggable = sortMode
            ? tile
            : kIsWeb
            ? Draggable<String>(
                data: task.id,
                dragAnchorStrategy: pointerDragAnchorStrategy,
                feedback: _dragFeedback(task),
                childWhenDragging: Opacity(opacity: 0.3, child: tile),
                onDragStarted: () {},
                onDragEnd: (_) => setState(() => _hoveredId = null),
                child: tile,
              )
            : LongPressDraggable<String>(
                data: task.id,
                dragAnchorStrategy: pointerDragAnchorStrategy,
                feedback: _dragFeedback(task),
                childWhenDragging: Opacity(opacity: 0.3, child: tile),
                onDragStarted: () {},
                onDragEnd: (_) => setState(() => _hoveredId = null),
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
    final rows = <Widget>[];

    for (var i = 0; i < tasks.length; i++) {
      if (rows.isNotEmpty) {
        rows.add(const Divider(height: 1, indent: _taskTitleIndent));
      }
      rows.add(_buildRow(tasks[i], tasks, i));
    }

    return Column(children: rows);
  }
}

class _TaskTile extends ConsumerWidget {
  final Task task;
  // Set while rearranging: shown instead of the delete button, and the row
  // stops opening the task so a stray tap does not leave sort mode behind
  final Widget? handle;
  const _TaskTile({required this.task, this.handle});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stringsProvider);
    // Not the selected date: in the all-tasks view each row is about its own
    // occurrence, so a monthly task ticks off against the 20th, not today
    final rowDate = ref.watch(taskRowDateProvider(task));
    final effectiveDate = DateTime(rowDate.year, rowDate.month, rowDate.day);
    final isCompleted = task.isCompletedOn(effectiveDate);
    final targets = ref.watch(semesterGoalsProvider);
    final cats = ref.watch(categoriesProvider);

    final linkedTarget = task.linkedTargetId != null
        ? targets.where((g) => g.id == task.linkedTargetId).firstOrNull
        : null;

    final targetColor = taskLinkColor(cats, linkedTarget,
        targetVision: visionOf(linkedTarget, ref.watch(futureGoalsProvider)));

    final hasSubtitle =
        task.content != null ||
        task.dueTime != null ||
        (task.recurrence != null && !task.recurrence!.isNone) ||
        linkedTarget != null;

    final tile = ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      // Drop ListTile's 72dp two-line floor so the row hugs its content, and
      // center it so a link-less task doesn't sit high against the checkbox
      minTileHeight: 0,
      minLeadingWidth: 0,
      horizontalTitleGap: AppSpacing.sm,
      // Top, not centre: a two-line title would otherwise push the tick box
      // and the delete button away from the first line
      titleAlignment: ListTileTitleAlignment.titleHeight,
      leading: TaskCheckbox(
        value: isCompleted,
        onToggle: () => ref.read(tasksProvider.notifier).toggleOnDate(task.id, effectiveDate),
        isLastOutstanding: () => _isLastOutstanding(ref, effectiveDate),
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
              ],
            )
          : null,
      trailing: handle ?? Row(
        mainAxisSize: MainAxisSize.min,
        children: [
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
      onTap: handle != null ? null : () => showTaskSheet(context, ref, existing: task),
    );

    // ListTile paints its ink splash on the nearest Material ancestor. The card
    // container and the drag-hover highlight are both DecoratedBoxes that would
    // otherwise sit in between and swallow the splash
    // A Stack, not IntrinsicHeight + Row. ListTile measures its intrinsic
    // height against the FULL width, so a title that wraps to two lines at the
    // real width still reports one line's worth and the subtitle below it gets
    // cut off. Letting the tile lay itself out and painting the bar over the
    // left edge keeps the row as tall as its content
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: _linkBarWidth),
            child: tile,
          ),
          Positioned(
            top: 0,
            bottom: 0,
            left: 0,
            child: LinkColorBar(top: targetColor),
          ),
        ],
      ),
    );
  }
}

// ─── Date+time picker (clock style) ──────────────────────────────────────────
