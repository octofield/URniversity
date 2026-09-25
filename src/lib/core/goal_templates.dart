import '../l10n/app_strings.dart';

// Starter templates for a brand new account.
//
// Four empty tabs tell a new user nothing about how the three layers relate, so
// a template writes one worked example into their own data: a semester goal,
// milestones under it, and daily tasks linked to a milestone.
//
// What it creates is ordinary data — no "this came from a template" flag — so
// editing and deleting behave exactly as they do for anything typed by hand.
typedef TemplateText = String Function(AppStrings);

class TemplateMilestone {
  final TemplateText title;
  final List<TemplateText> tasks;

  const TemplateMilestone(this.title, {this.tasks = const []});
}

class TemplateGoal {
  final TemplateText title;
  final List<String> categories;
  final List<TemplateMilestone> milestones;

  const TemplateGoal(
    this.title, {
    this.categories = const [],
    this.milestones = const [],
  });
}

class GoalTemplate {
  final String id;
  final TemplateText name;
  final TemplateText description;
  final List<TemplateGoal> goals;

  const GoalTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.goals,
  });

  int get goalCount =>
      goals.length + goals.fold(0, (n, g) => n + g.milestones.length);

  int get taskCount =>
      goals.fold(0, (n, g) => n + g.milestones.fold(0, (m, ms) => m + ms.tasks.length));
}

const kGoalTemplates = <GoalTemplate>[
  GoalTemplate(
    id: 'freshman',
    name: _freshmanName,
    description: _freshmanDesc,
    goals: [
      TemplateGoal(
        _freshmanG1,
        milestones: [
          TemplateMilestone(_freshmanG1M1, tasks: [_freshmanG1T1]),
          TemplateMilestone(_freshmanG1M2),
        ],
      ),
      TemplateGoal(
        _freshmanG2,
        milestones: [
          TemplateMilestone(_freshmanG2M1, tasks: [_freshmanG2T1]),
          TemplateMilestone(_freshmanG2M2),
        ],
      ),
    ],
  ),
  GoalTemplate(
    id: 'exchange',
    name: _exchangeName,
    description: _exchangeDesc,
    goals: [
      TemplateGoal(
        _exchangeG1,
        categories: ['exchange'],
        milestones: [
          TemplateMilestone(_exchangeG1M1, tasks: [_exchangeG1T1]),
          TemplateMilestone(_exchangeG1M2),
        ],
      ),
      TemplateGoal(
        _exchangeG2,
        categories: ['exchange'],
        milestones: [
          TemplateMilestone(_exchangeG2M1, tasks: [_exchangeG2T1]),
          TemplateMilestone(_exchangeG2M2),
        ],
      ),
    ],
  ),
  GoalTemplate(
    id: 'intern',
    name: _internName,
    description: _internDesc,
    goals: [
      TemplateGoal(
        _internG1,
        categories: ['intern'],
        milestones: [
          TemplateMilestone(_internG1M1, tasks: [_internG1T1]),
          TemplateMilestone(_internG1M2),
        ],
      ),
      TemplateGoal(
        _internG2,
        categories: ['intern'],
        milestones: [
          TemplateMilestone(_internG2M1, tasks: [_internG2T1]),
          TemplateMilestone(_internG2M2),
        ],
      ),
    ],
  ),
];

// Torn out as top-level functions because a const list cannot hold a closure
String _freshmanName(AppStrings s) => s.tplFreshman;
String _freshmanDesc(AppStrings s) => s.tplFreshmanDesc;
String _freshmanG1(AppStrings s) => s.tplFreshmanG1;
String _freshmanG1M1(AppStrings s) => s.tplFreshmanG1M1;
String _freshmanG1M2(AppStrings s) => s.tplFreshmanG1M2;
String _freshmanG1T1(AppStrings s) => s.tplFreshmanG1T1;
String _freshmanG2(AppStrings s) => s.tplFreshmanG2;
String _freshmanG2M1(AppStrings s) => s.tplFreshmanG2M1;
String _freshmanG2M2(AppStrings s) => s.tplFreshmanG2M2;
String _freshmanG2T1(AppStrings s) => s.tplFreshmanG2T1;

String _exchangeName(AppStrings s) => s.tplExchange;
String _exchangeDesc(AppStrings s) => s.tplExchangeDesc;
String _exchangeG1(AppStrings s) => s.tplExchangeG1;
String _exchangeG1M1(AppStrings s) => s.tplExchangeG1M1;
String _exchangeG1M2(AppStrings s) => s.tplExchangeG1M2;
String _exchangeG1T1(AppStrings s) => s.tplExchangeG1T1;
String _exchangeG2(AppStrings s) => s.tplExchangeG2;
String _exchangeG2M1(AppStrings s) => s.tplExchangeG2M1;
String _exchangeG2M2(AppStrings s) => s.tplExchangeG2M2;
String _exchangeG2T1(AppStrings s) => s.tplExchangeG2T1;

String _internName(AppStrings s) => s.tplIntern;
String _internDesc(AppStrings s) => s.tplInternDesc;
String _internG1(AppStrings s) => s.tplInternG1;
String _internG1M1(AppStrings s) => s.tplInternG1M1;
String _internG1M2(AppStrings s) => s.tplInternG1M2;
String _internG1T1(AppStrings s) => s.tplInternG1T1;
String _internG2(AppStrings s) => s.tplInternG2;
String _internG2M1(AppStrings s) => s.tplInternG2M1;
String _internG2M2(AppStrings s) => s.tplInternG2M2;
String _internG2T1(AppStrings s) => s.tplInternG2T1;
