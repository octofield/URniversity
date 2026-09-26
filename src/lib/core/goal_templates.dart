import '../l10n/app_strings.dart';
import '../models/future_goal.dart' show FutureCategories;

// Starter templates for a brand new account.
//
// Four empty tabs tell a new user nothing about how the three layers relate, so
// a template writes one worked example into their own data: a vision, the
// semester goals linked to it, milestones under those, and tasks linked to a
// milestone.
//
// What it creates is ordinary data — no "this came from a template" flag — so
// editing and deleting behave exactly as they do for anything typed by hand.
typedef TemplateText = String Function(AppStrings);

class TemplateMilestone {
  final TemplateText title;
  final List<TemplateText> tasks;

  const TemplateMilestone(this.title, {this.tasks = const []});
}

class TemplateVision {
  final TemplateText title;
  final List<String> categories;

  const TemplateVision(this.title, {this.categories = const [FutureCategories.other]});
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
  final TemplateVision vision;
  final List<TemplateGoal> goals;

  const GoalTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.vision,
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
    vision: TemplateVision(_freshmanVision),
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
    vision: TemplateVision(_exchangeVision, categories: [FutureCategories.exchange]),
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
    vision: TemplateVision(_internVision, categories: [FutureCategories.intern]),
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
  GoalTemplate(
    id: 'grad',
    name: _gradName,
    description: _gradDesc,
    vision: TemplateVision(_gradVision),
    goals: [
      TemplateGoal(
        _gradG1,
        milestones: [
          TemplateMilestone(_gradG1M1, tasks: [_gradG1T1]),
          TemplateMilestone(_gradG1M2),
        ],
      ),
      TemplateGoal(
        _gradG2,
        milestones: [
          TemplateMilestone(_gradG2M1, tasks: [_gradG2T1]),
          TemplateMilestone(_gradG2M2),
        ],
      ),
    ],
  ),
  GoalTemplate(
    id: 'cert',
    name: _certName,
    description: _certDesc,
    vision: TemplateVision(_certVision, categories: [FutureCategories.certification]),
    goals: [
      TemplateGoal(
        _certG1,
        categories: [FutureCategories.certification],
        milestones: [
          TemplateMilestone(_certG1M1, tasks: [_certG1T1]),
          TemplateMilestone(_certG1M2),
        ],
      ),
      TemplateGoal(
        _certG2,
        categories: [FutureCategories.competition],
        milestones: [
          TemplateMilestone(_certG2M1, tasks: [_certG2T1]),
          TemplateMilestone(_certG2M2),
        ],
      ),
    ],
  ),
  GoalTemplate(
    id: 'major',
    name: _majorName,
    description: _majorDesc,
    vision: TemplateVision(_majorVision),
    goals: [
      TemplateGoal(
        _majorG1,
        milestones: [
          TemplateMilestone(_majorG1M1, tasks: [_majorG1T1]),
          TemplateMilestone(_majorG1M2),
        ],
      ),
      TemplateGoal(
        _majorG2,
        milestones: [
          TemplateMilestone(_majorG2M1, tasks: [_majorG2T1]),
          TemplateMilestone(_majorG2M2),
        ],
      ),
    ],
  ),
  GoalTemplate(
    id: 'health',
    name: _healthName,
    description: _healthDesc,
    vision: TemplateVision(_healthVision),
    goals: [
      TemplateGoal(
        _healthG1,
        milestones: [
          TemplateMilestone(_healthG1M1, tasks: [_healthG1T1]),
          TemplateMilestone(_healthG1M2),
        ],
      ),
      TemplateGoal(
        _healthG2,
        milestones: [
          TemplateMilestone(_healthG2M1, tasks: [_healthG2T1]),
          TemplateMilestone(_healthG2M2),
        ],
      ),
    ],
  ),
];

// Torn out as top-level functions because a const list cannot hold a closure
String _freshmanName(AppStrings s) => s.tplFreshman;
String _freshmanDesc(AppStrings s) => s.tplFreshmanDesc;
String _freshmanVision(AppStrings s) => s.tplFreshmanVision;
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
String _exchangeVision(AppStrings s) => s.tplExchangeVision;
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
String _internVision(AppStrings s) => s.tplInternVision;
String _internG1(AppStrings s) => s.tplInternG1;
String _internG1M1(AppStrings s) => s.tplInternG1M1;
String _internG1M2(AppStrings s) => s.tplInternG1M2;
String _internG1T1(AppStrings s) => s.tplInternG1T1;
String _internG2(AppStrings s) => s.tplInternG2;
String _internG2M1(AppStrings s) => s.tplInternG2M1;
String _internG2M2(AppStrings s) => s.tplInternG2M2;
String _internG2T1(AppStrings s) => s.tplInternG2T1;

String _gradName(AppStrings s) => s.tplGrad;
String _gradDesc(AppStrings s) => s.tplGradDesc;
String _gradVision(AppStrings s) => s.tplGradVision;
String _gradG1(AppStrings s) => s.tplGradG1;
String _gradG1M1(AppStrings s) => s.tplGradG1M1;
String _gradG1M2(AppStrings s) => s.tplGradG1M2;
String _gradG1T1(AppStrings s) => s.tplGradG1T1;
String _gradG2(AppStrings s) => s.tplGradG2;
String _gradG2M1(AppStrings s) => s.tplGradG2M1;
String _gradG2M2(AppStrings s) => s.tplGradG2M2;
String _gradG2T1(AppStrings s) => s.tplGradG2T1;

String _certName(AppStrings s) => s.tplCert;
String _certDesc(AppStrings s) => s.tplCertDesc;
String _certVision(AppStrings s) => s.tplCertVision;
String _certG1(AppStrings s) => s.tplCertG1;
String _certG1M1(AppStrings s) => s.tplCertG1M1;
String _certG1M2(AppStrings s) => s.tplCertG1M2;
String _certG1T1(AppStrings s) => s.tplCertG1T1;
String _certG2(AppStrings s) => s.tplCertG2;
String _certG2M1(AppStrings s) => s.tplCertG2M1;
String _certG2M2(AppStrings s) => s.tplCertG2M2;
String _certG2T1(AppStrings s) => s.tplCertG2T1;

String _majorName(AppStrings s) => s.tplMajor;
String _majorDesc(AppStrings s) => s.tplMajorDesc;
String _majorVision(AppStrings s) => s.tplMajorVision;
String _majorG1(AppStrings s) => s.tplMajorG1;
String _majorG1M1(AppStrings s) => s.tplMajorG1M1;
String _majorG1M2(AppStrings s) => s.tplMajorG1M2;
String _majorG1T1(AppStrings s) => s.tplMajorG1T1;
String _majorG2(AppStrings s) => s.tplMajorG2;
String _majorG2M1(AppStrings s) => s.tplMajorG2M1;
String _majorG2M2(AppStrings s) => s.tplMajorG2M2;
String _majorG2T1(AppStrings s) => s.tplMajorG2T1;

String _healthName(AppStrings s) => s.tplHealth;
String _healthDesc(AppStrings s) => s.tplHealthDesc;
String _healthVision(AppStrings s) => s.tplHealthVision;
String _healthG1(AppStrings s) => s.tplHealthG1;
String _healthG1M1(AppStrings s) => s.tplHealthG1M1;
String _healthG1M2(AppStrings s) => s.tplHealthG1M2;
String _healthG1T1(AppStrings s) => s.tplHealthG1T1;
String _healthG2(AppStrings s) => s.tplHealthG2;
String _healthG2M1(AppStrings s) => s.tplHealthG2M1;
String _healthG2M2(AppStrings s) => s.tplHealthG2M2;
String _healthG2T1(AppStrings s) => s.tplHealthG2T1;
