import '../utils/category_helpers.dart';
import 'category.dart';
import 'course.dart';
import 'future_goal.dart';
import 'semester_goal.dart';

// One row of friend_list() (data_dictionary.md D40): someone the user is
// friends with, or a request either way. Nothing here is stored on the device
enum FriendStatus { incoming, outgoing, friend }

// What a user lets every friend see (D8-C). Off until switched on
class FriendShares {
  final bool graph;
  final bool rates;
  final bool timetable;

  const FriendShares({this.graph = false, this.rates = false, this.timetable = false});

  bool get any => graph || rates || timetable;

  FriendShares copyWith({bool? graph, bool? rates, bool? timetable}) => FriendShares(
        graph: graph ?? this.graph,
        rates: rates ?? this.rates,
        timetable: timetable ?? this.timetable,
      );

  factory FriendShares.fromJson(Map<String, dynamic> j) => FriendShares(
        graph: j['share_graph'] as bool? ?? false,
        rates: j['share_rates'] as bool? ?? false,
        timetable: j['share_timetable'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'share_graph': graph,
        'share_rates': rates,
        'share_timetable': timetable,
      };

  @override
  bool operator ==(Object other) =>
      other is FriendShares && other.graph == graph && other.rates == rates && other.timetable == timetable;

  @override
  int get hashCode => Object.hash(graph, rates, timetable);
}

class FriendEntry {
  // The friendships row: what accepting, declining or removing names
  final String friendshipId;
  final String userId;
  final String? name;
  final int? avatarIndex;
  final String? avatarUrl;
  final FriendStatus status;
  // Always all off for a request: friend_list() tells only friends
  final FriendShares shares;

  const FriendEntry({
    required this.friendshipId,
    required this.userId,
    this.name,
    this.avatarIndex,
    this.avatarUrl,
    required this.status,
    this.shares = const FriendShares(),
  });

  factory FriendEntry.fromJson(Map<String, dynamic> j) => FriendEntry(
        friendshipId: '${j['friendship_id']}',
        userId: j['user_id'] as String,
        name: j['name'] as String?,
        avatarIndex: (j['avatar_index'] as num?)?.toInt(),
        avatarUrl: j['avatar_url'] as String?,
        status: switch (j['status']) {
          'incoming' => FriendStatus.incoming,
          'outgoing' => FriendStatus.outgoing,
          _ => FriendStatus.friend,
        },
        shares: FriendShares.fromJson(j),
      );
}

// Whose invite code this is (friend_code_owner()), shown before sending
class FriendPreview {
  final String userId;
  final String? name;
  final int? avatarIndex;
  final String? avatarUrl;
  final bool isSelf;

  const FriendPreview({required this.userId, this.name, this.avatarIndex, this.avatarUrl, this.isSelf = false});

  factory FriendPreview.fromJson(Map<String, dynamic> j) => FriendPreview(
        userId: j['user_id'] as String,
        name: j['name'] as String?,
        avatarIndex: (j['avatar_index'] as num?)?.toInt(),
        avatarUrl: j['avatar_url'] as String?,
        isSelf: j['is_self'] as bool? ?? false,
      );
}

// A friend's timetable for one semester (friend_timetable()): names, colours
// and times only. Their school picks the period table it is drawn with
class FriendTimetable {
  final String? school;
  final List<Course> courses;

  const FriendTimetable({this.school, this.courses = const []});

  factory FriendTimetable.fromJson(Map<String, dynamic> j, String semester) => FriendTimetable(
        school: j['school'] as String?,
        courses: [
          for (final c in (j['courses'] as List<dynamic>? ?? const []))
            _course((c as Map).cast<String, dynamic>(), semester),
        ],
      );

  static Course _course(Map<String, dynamic> j, String semester) => Course(
        id: '${j['id']}',
        semester: semester,
        title: j['title'] as String? ?? '',
        color: (j['color'] as num?)?.toInt() ?? 0xFF4A90C4,
        sessions: [
          for (final s in (j['sessions'] as List<dynamic>? ?? const []))
            CourseSession.fromJson((s as Map).cast<String, dynamic>()),
        ],
        // Not sent: nothing here is kept or sorted by it
        createdAt: DateTime(2000),
      );
}

// A friend's planning graph (friend_graph()): their visions and top-level
// targets, how many tasks hang off each target, and their own category colours
// and icons — a custom category of theirs is not in the user's list
class FriendGraph {
  final List<FutureGoal> futures;
  final List<SemesterGoal> semesters;
  final Map<String, int> taskCounts;
  final List<CategoryEntry> categories;

  const FriendGraph({
    this.futures = const [],
    this.semesters = const [],
    this.taskCounts = const {},
    this.categories = const [],
  });

  factory FriendGraph.fromJson(Map<String, dynamic> j) {
    final cats = (j['categories'] as Map?)?.cast<String, dynamic>();
    final styles = (cats?['styles'] as Map?)?.cast<String, dynamic>() ?? const {};
    final ids = (cats?['ordered_list'] as List<dynamic>?)?.cast<String>() ?? FutureCategories.builtIns;
    return FriendGraph(
      futures: [
        for (final g in (j['futures'] as List<dynamic>? ?? const []))
          FutureGoal.fromJson((g as Map).cast<String, dynamic>()),
      ],
      semesters: [
        for (final g in (j['semesters'] as List<dynamic>? ?? const []))
          SemesterGoal.fromJson((g as Map).cast<String, dynamic>()),
      ],
      taskCounts: {
        for (final e in ((j['counts'] as Map?)?.cast<String, dynamic>() ?? const {}).entries)
          e.key: (e.value as num).toInt(),
      },
      // As CategoriesNotifier reads the user's own (categories_provider.dart)
      categories: [
        for (final id in ids)
          styles[id] != null
              ? CategoryEntry.fromJson(id, (styles[id] as Map).cast<String, dynamic>())
              : CategoryEntry(id: id, color: defaultCatColor(id), icon: defaultCatIcon(id)),
      ],
    );
  }
}
