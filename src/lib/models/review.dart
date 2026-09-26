// A finished review: the numbers as they stood when it was done, the three
// answers, and the targets picked to focus on next. The numbers are a snapshot
// on purpose — editing a task later must not rewrite what a past review said.
enum ReviewPeriod { week, month, semester }

class Review {
  final String id;
  final ReviewPeriod period;
  // Both inclusive, date only
  final DateTime periodStart;
  final DateTime periodEnd;
  final String? wentWell;
  final String? stuck;
  final String? nextFocus;
  // Not foreign keys: a target deleted since is simply skipped when shown
  final List<String> focusTargetIds;
  final ReviewStats stats;
  final DateTime createdAt;

  const Review({
    required this.id,
    required this.period,
    required this.periodStart,
    required this.periodEnd,
    this.wentWell,
    this.stuck,
    this.nextFocus,
    this.focusTargetIds = const [],
    required this.stats,
    required this.createdAt,
  });

  factory Review.fromJson(Map<String, dynamic> j) => Review(
        id: j['id'] as String,
        period: ReviewPeriod.values.firstWhere(
          (p) => p.name == j['period'],
          // A value from a newer build: shown as a weekly one rather than lost
          orElse: () => ReviewPeriod.week,
        ),
        periodStart: DateTime.parse(j['period_start'] as String),
        periodEnd: DateTime.parse(j['period_end'] as String),
        wentWell: j['went_well'] as String?,
        stuck: j['stuck'] as String?,
        nextFocus: j['next_focus'] as String?,
        focusTargetIds: (j['focus_target_ids'] as List<dynamic>? ?? const []).cast<String>(),
        stats: ReviewStats.fromJson((j['stats'] as Map?)?.cast<String, dynamic>() ?? const {}),
        createdAt: DateTime.parse(j['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'period': period.name,
        'period_start': _date(periodStart),
        'period_end': _date(periodEnd),
        'went_well': wentWell,
        'stuck': stuck,
        'next_focus': nextFocus,
        'focus_target_ids': focusTargetIds,
        'stats': stats.toJson(),
        'created_at': createdAt.toIso8601String(),
      };

  Review copyWith({
    String? wentWell,
    String? stuck,
    String? nextFocus,
    List<String>? focusTargetIds,
    ReviewStats? stats,
  }) =>
      Review(
        id: id,
        period: period,
        periodStart: periodStart,
        periodEnd: periodEnd,
        wentWell: wentWell ?? this.wentWell,
        stuck: stuck ?? this.stuck,
        nextFocus: nextFocus ?? this.nextFocus,
        focusTargetIds: focusTargetIds ?? this.focusTargetIds,
        stats: stats ?? this.stats,
        createdAt: createdAt,
      );
}

// A Postgres date column wants the day and nothing else
String _date(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

class TargetProgress {
  final String id;
  final String title;
  // Milestones finished out of all of them, as they stood at review time
  final int milestonesDone;
  final int milestonesTotal;
  // Tasks under this target done in the period, out of those that fell in it
  final int tasksDone;
  final int tasksTotal;

  const TargetProgress({
    required this.id,
    required this.title,
    required this.milestonesDone,
    required this.milestonesTotal,
    required this.tasksDone,
    required this.tasksTotal,
  });

  factory TargetProgress.fromJson(Map<String, dynamic> j) => TargetProgress(
        id: j['id'] as String? ?? '',
        title: j['title'] as String? ?? '',
        milestonesDone: j['ms_done'] as int? ?? 0,
        milestonesTotal: j['ms_total'] as int? ?? 0,
        tasksDone: j['done'] as int? ?? 0,
        tasksTotal: j['total'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'ms_done': milestonesDone,
        'ms_total': milestonesTotal,
        'done': tasksDone,
        'total': tasksTotal,
      };
}

class ReviewStats {
  final int done;
  final int total;
  // Null when nothing was planned in the period
  final double? rate;
  // The period before, for the "up 13%" line; null when it had nothing planned
  final double? previousRate;
  final int streak;
  // 1 = Monday; null when no day had anything planned
  final int? bestWeekday;
  final int journals;
  final List<TargetProgress> targets;
  // A semester review only: that semester's GPA as it stood (Phase 6); null
  // for weeks and months, or with no grades yet
  final double? gpa;

  const ReviewStats({
    required this.done,
    required this.total,
    this.rate,
    this.previousRate,
    required this.streak,
    this.bestWeekday,
    required this.journals,
    this.targets = const [],
    this.gpa,
  });

  // Every field falls back: a snapshot written by an older build may be missing
  // the newer keys, and the answers next to it are still worth showing
  factory ReviewStats.fromJson(Map<String, dynamic> j) => ReviewStats(
        done: j['done'] as int? ?? 0,
        total: j['total'] as int? ?? 0,
        rate: (j['rate'] as num?)?.toDouble(),
        previousRate: (j['prev_rate'] as num?)?.toDouble(),
        streak: j['streak'] as int? ?? 0,
        bestWeekday: j['best_weekday'] as int?,
        journals: j['journals'] as int? ?? 0,
        targets: [
          for (final t in (j['targets'] as List<dynamic>? ?? const []))
            TargetProgress.fromJson((t as Map).cast<String, dynamic>()),
        ],
        gpa: (j['gpa'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'done': done,
        'total': total,
        'rate': rate,
        'prev_rate': previousRate,
        'streak': streak,
        'best_weekday': bestWeekday,
        'journals': journals,
        'targets': [for (final t in targets) t.toJson()],
        'gpa': gpa,
      };
}
