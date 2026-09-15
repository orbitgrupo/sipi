// Sipi — modelos de datos (espejo de la API del backend).
class User {
  final int id;
  final String name;
  final String email;
  final String role;
  User(
      {required this.id,
      required this.name,
      required this.email,
      required this.role});
  factory User.fromJson(Map<String, dynamic> j) => User(
      id: j['id'],
      name: j['name'],
      email: j['email'],
      role: j['role'] ?? 'user');
}

class Balance {
  final int points;
  final int pendingPoints;
  final int earnedPoints;
  final int usedPoints;
  final double usd;
  final int pointsPerUsd;
  final int level;
  Balance({
    required this.points,
    required this.pendingPoints,
    required this.earnedPoints,
    required this.usedPoints,
    required this.usd,
    required this.pointsPerUsd,
    required this.level,
  });
  factory Balance.fromJson(Map<String, dynamic> j) => Balance(
        points: j['points'] ?? 0,
        pendingPoints: j['pending_points'] ?? 0,
        earnedPoints: j['earned_points'] ?? 0,
        usedPoints: j['used_points'] ?? 0,
        usd: (j['usd'] ?? 0).toDouble(),
        pointsPerUsd: j['points_per_usd'] ?? 50,
        level: j['level'] ?? 1,
      );
}

class Task {
  final int id;
  final String title;
  final String description;
  final String instructions;
  final String category;
  final int points;
  final int estimatedMinutes;
  final String verification;
  final String requirements;
  final String targetUrl;
  final String? myStatus;
  Task({
    required this.id,
    required this.title,
    required this.description,
    required this.instructions,
    required this.category,
    required this.points,
    required this.estimatedMinutes,
    required this.verification,
    required this.requirements,
    required this.targetUrl,
    this.myStatus,
  });
  factory Task.fromJson(Map<String, dynamic> j) => Task(
        id: j['id'],
        title: j['title'] ?? '',
        description: j['description'] ?? '',
        instructions: j['instructions'] ?? '',
        category: j['category'] ?? 'otras',
        points: j['points'] ?? 0,
        estimatedMinutes: j['estimated_minutes'] ?? 5,
        verification: j['verification'] ?? 'manual',
        requirements: j['requirements'] ?? '',
        targetUrl: j['target_url'] ?? '',
        myStatus: j['my_status'],
      );
}

class TaskCompletion {
  final int id;
  final String status;
  TaskCompletion({required this.id, required this.status});
  factory TaskCompletion.fromJson(Map<String, dynamic> j) =>
      TaskCompletion(id: j['id'], status: j['status'] ?? 'pending');
}

class SurveyQuestion {
  final String id;
  final String type; // single | multiple | yesno | scale | text
  final String text;
  final List<String> options;
  final bool required;
  final int min;
  final int max;
  SurveyQuestion({
    required this.id,
    required this.type,
    required this.text,
    this.options = const [],
    this.required = false,
    this.min = 1,
    this.max = 5,
  });
  factory SurveyQuestion.fromJson(Map<String, dynamic> j) => SurveyQuestion(
        id: j['id'],
        type: j['type'],
        text: j['text'] ?? '',
        options:
            (j['options'] as List? ?? []).map((e) => e.toString()).toList(),
        required: j['required'] ?? false,
        min: j['min'] ?? 1,
        max: j['max'] ?? 5,
      );
}

class Survey {
  final int id;
  final int taskId;
  final String title;
  final List<SurveyQuestion> questions;
  final bool answered;
  Survey(
      {required this.id,
      required this.taskId,
      required this.title,
      required this.questions,
      required this.answered});
  factory Survey.fromJson(Map<String, dynamic> j) {
    final s = j['survey'] ?? j;
    return Survey(
      id: s['id'],
      taskId: s['task_id'] ?? 0,
      title: s['title'] ?? '',
      questions: ((s['questions'] as List?) ?? [])
          .map((q) => SurveyQuestion.fromJson(q))
          .toList(),
      answered: j['answered'] ?? false,
    );
  }
}

class Achievement {
  final String code;
  final String name;
  final String description;
  final int threshold;
  final int bonusPoints;
  final bool earned;
  final int progress;
  Achievement({
    required this.code,
    required this.name,
    required this.description,
    required this.threshold,
    required this.bonusPoints,
    required this.earned,
    required this.progress,
  });
  factory Achievement.fromJson(Map<String, dynamic> j) => Achievement(
        code: j['code'],
        name: j['name'],
        description: j['description'] ?? '',
        threshold: j['threshold'] ?? 0,
        bonusPoints: j['bonus_points'] ?? 0,
        earned: j['earned'] ?? false,
        progress: j['progress'] ?? 0,
      );
}

class Redemption {
  final int id;
  final int points;
  final double amountUsd;
  final String status;
  final String createdAt;
  Redemption(
      {required this.id,
      required this.points,
      required this.amountUsd,
      required this.status,
      required this.createdAt});
  factory Redemption.fromJson(Map<String, dynamic> j) => Redemption(
        id: j['id'],
        points: j['points'],
        amountUsd: (j['amount_usd'] ?? 0).toDouble(),
        status: j['status'] ?? 'pending',
        createdAt: j['created_at'] ?? '',
      );
}

class LedgerMovement {
  final String type;
  final int points;
  final int balanceAfter;
  final String note;
  final String createdAt;
  LedgerMovement(
      {required this.type,
      required this.points,
      required this.balanceAfter,
      required this.note,
      required this.createdAt});
  factory LedgerMovement.fromJson(Map<String, dynamic> j) => LedgerMovement(
        type: j['type'] ?? '',
        points: j['points'] ?? 0,
        balanceAfter: j['balance_after'] ?? 0,
        note: j['note'] ?? '',
        createdAt: j['created_at'] ?? '',
      );
}

class SipiNotification {
  final int id;
  final String type;
  final String title;
  final String body;
  final bool read;
  final String createdAt;
  SipiNotification(
      {required this.id,
      required this.type,
      required this.title,
      required this.body,
      required this.read,
      required this.createdAt});
  factory SipiNotification.fromJson(Map<String, dynamic> j) => SipiNotification(
        id: j['id'],
        type: j['type'] ?? '',
        title: j['title'] ?? '',
        body: j['body'] ?? '',
        read: (j['is_read'] ?? 0) == 1,
        createdAt: j['created_at'] ?? '',
      );
}

/// Etiquetas e iconos por categoría (coherentes con el mockup).
class CategoryMeta {
  static const labels = {
    'social': 'Redes sociales',
    'encuestas': 'Encuestas',
    'productos': 'Productos',
    'opinion': 'Opinión',
    'promociones': 'Promociones',
    'otras': 'Otras',
  };
  static String label(String c) => labels[c] ?? c;
}
