import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/app_strings.dart';
import '../providers/future_goals_provider.dart';
import '../providers/inspirations_provider.dart';
import '../providers/journal_provider.dart';
import '../providers/semester_goals_provider.dart';
import '../providers/tasks_provider.dart';
import '../widgets/coach_mark.dart';

// The four tour chapters, one per tab (kTourChapters). Each stop is one thing
// to do; an `open` … `close` pair is the user doing it for real in the actual
// sheet, one highlighted field at a time. The anchor ids are the TourAnchor
// ids placed on those widgets across the screens.
List<CoachMarkStep> tourChapter(String id, WidgetRef ref, AppStrings s) {
  const info = TourStepKind.info;
  const field = TourStepKind.field;
  const tap = TourStepKind.tap;
  const open = TourStepKind.open;
  const close = TourStepKind.close;

  int tasks() => ref.read(tasksProvider).length;
  int ideas() => ref.read(inspirationsProvider).length;
  int targets() => ref.read(semesterGoalsProvider).where((g) => g.parentId == null).length;
  int milestones() => ref.read(semesterGoalsProvider).where((g) => g.parentId != null).length;
  int visions() => ref.read(futureGoalsProvider).length;
  // Only entries the user wrote: the provider also back-fills forgotten days
  int journals() => ref.read(journalProvider).where(JournalNotifier.isWrittenByUser).length;
  bool hasTargetHere() {
    final semester = ref.read(selectedSemesterProvider);
    return ref.read(semesterGoalsProvider).any((g) => g.parentId == null && g.semester == semester);
  }

  return switch (id) {
    'today' => [
        CoachMarkStep(open, anchor: 'fab.add', title: s.tourTaskAddTitle, body: s.tourTaskAddBody, count: tasks),
        CoachMarkStep(field, anchor: 'task.title', body: s.tourTaskTitleBody),
        CoachMarkStep(field, anchor: 'task.due', body: s.tourTaskDueBody),
        CoachMarkStep(field, anchor: 'task.repeat', body: s.tourTaskRepeatBody),
        CoachMarkStep(field, anchor: 'task.link', body: s.tourTaskLinkBody),
        CoachMarkStep(close, anchor: 'task.submit', body: s.tourTaskSubmitBody),
        CoachMarkStep(open, anchor: 'today.summary', title: s.tourSummaryTitle, body: s.tourSummaryBody),
        CoachMarkStep(close, anchor: 'history.summary', body: s.tourHistoryBody),
        CoachMarkStep(info, anchor: 'today.timetable', title: s.tourTimetableTitle, body: s.tourTimetableBody),
        // After the progress and timetable cards, not before: the weekly view
        // has neither, and trying out the switch may well leave the user there
        CoachMarkStep(tap, anchor: 'today.viewSwitch', title: s.tourViewTitle, body: s.tourViewBody),
        CoachMarkStep(open, anchor: 'fab.inspiration', title: s.tourInspAddTitle, body: s.tourInspAddBody, count: ideas),
        CoachMarkStep(field, anchor: 'insp.title', body: s.tourInspTitleBody),
        CoachMarkStep(close, anchor: 'insp.submit', body: s.tourSubmitBody),
        CoachMarkStep(tap, anchor: 'nav.1', title: s.tourNextTargetTitle, body: s.tourNextTargetBody),
      ],
    'semester' => [
        CoachMarkStep(info, anchor: 'semester.templates', title: s.tourTemplatesTitle, body: s.tourTemplatesBody),
        CoachMarkStep(open, anchor: 'fab.add', title: s.tourTargetAddTitle, body: s.tourTargetAddBody, count: targets),
        CoachMarkStep(field, anchor: 'goal.title', body: s.tourTargetTitleBody),
        CoachMarkStep(field, anchor: 'goal.categories', body: s.tourTargetCategoryBody),
        CoachMarkStep(field, anchor: 'goal.semester', body: s.tourTargetSemesterBody),
        // Pointless until there is a vision to link to
        CoachMarkStep(field, anchor: 'goal.vision', body: s.tourTargetVisionBody, when: () => visions() > 0),
        CoachMarkStep(close, anchor: 'goal.submit', body: s.tourSubmitBody),
        // Milestones live on a target's own page, so this needs a target —
        // skipped whole if the user passed on making one
        CoachMarkStep(open, anchor: 'semester.firstCard', title: s.tourMilestoneOpenTitle, body: s.tourMilestoneOpenBody, when: hasTargetHere),
        CoachMarkStep(open, anchor: 'detail.addMilestone', title: s.tourMilestoneAddTitle, body: s.tourMilestoneAddBody, count: milestones),
        CoachMarkStep(field, anchor: 'goal.title', body: s.tourMilestoneTitleBody),
        CoachMarkStep(close, anchor: 'goal.submit', body: s.tourSubmitBody),
        CoachMarkStep(close, anchor: 'detail.milestones', body: s.tourMilestoneListBody),
        CoachMarkStep(info, anchor: 'semester.picker', title: s.tourPickerTitle, body: s.tourPickerBody),
        CoachMarkStep(tap, anchor: 'nav.2', title: s.tourNextGoalTitle, body: s.tourNextGoalBody),
      ],
    'future' => [
        CoachMarkStep(open, anchor: 'fab.add', title: s.tourVisionAddTitle, body: s.tourVisionAddBody, count: visions),
        CoachMarkStep(field, anchor: 'vision.title', body: s.tourVisionTitleBody),
        CoachMarkStep(field, anchor: 'vision.categories', body: s.tourVisionCategoryBody),
        CoachMarkStep(field, anchor: 'vision.semesters', body: s.tourVisionSemestersBody),
        CoachMarkStep(close, anchor: 'vision.submit', body: s.tourSubmitBody),
        CoachMarkStep(open, anchor: 'future.firstCard', title: s.tourVisionOpenTitle, body: s.tourVisionOpenBody, when: () => visions() > 0),
        CoachMarkStep(close, anchor: 'visionDetail.linkedTargets', body: s.tourVisionLinkedBody),
        CoachMarkStep(info, anchor: 'future.filters', title: s.tourFiltersTitle, body: s.tourFiltersBody),
        CoachMarkStep(tap, anchor: 'nav.3', title: s.tourNextMeTitle, body: s.tourNextMeBody),
      ],
    'me' => [
        CoachMarkStep(info, anchor: 'me.summary', title: s.tourMeSummaryTitle, body: s.tourMeSummaryBody),
        CoachMarkStep(open, anchor: 'me.journal.add', title: s.tourJournalAddTitle, body: s.tourJournalAddBody, count: journals),
        CoachMarkStep(field, anchor: 'journal.content', body: s.tourJournalContentBody),
        CoachMarkStep(close, anchor: 'journal.save', body: s.tourSubmitBody),
        CoachMarkStep(open, anchor: 'me.inspirations.open', title: s.tourInspOpenTitle, body: s.tourInspOpenBody),
        CoachMarkStep(close, anchor: 'inspirations.list', body: s.tourInspListBody),
        CoachMarkStep(info, anchor: 'me.reviews', title: s.tourReviewsTitle, body: s.tourReviewsBody),
        CoachMarkStep(info, anchor: 'me.journals.open', title: s.tourJournalsTitle, body: s.tourJournalsBody),
        CoachMarkStep(info, anchor: 'me.settings', title: s.tourReplayTitle, body: s.tourReplayBody),
      ],
    _ => const [],
  };
}
