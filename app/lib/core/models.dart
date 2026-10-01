// Sipi — modelos de datos (espejo de la API del backend).

/// La API puede devolver enteros como número o como string (bigint de
/// PostgreSQL); estos helpers los normalizan para que la app no se rompa
/// al sincronizar datos creados en el panel.
int asInt(dynamic v, [int fallback = 0]) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v == null) return fallback;
  return int.tryParse(v.toString()) ?? fallback;
}

double asDouble(dynamic v, [double fallback = 0]) {
  if (v is double) return v;
  if (v is num) return v.toDouble();
  if (v == null) return fallback;
  return double.tryParse(v.toString()) ?? fallback;
}

bool asBool(dynamic v) => v == true || v == 1 || v == '1' || v == 'true';

class User {
  final String id;
  final String name;
  final String email;
  final String role;
  final bool approved;
  User(
      {required this.id,
      required this.name,
      required this.email,
      required this.role,
      this.approved = true});
  factory User.fromJson(Map<String, dynamic> j) => User(
      id: j['id'].toString(),
      name: j['name'],
      email: j['email'],
      role: j['role'] ?? 'user',
      approved: j['approved'] != 0 && j['approved'] != false);
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
        points: asInt(j['points']),
        pendingPoints: asInt(j['pending_points']),
        earnedPoints: asInt(j['earned_points']),
        usedPoints: asInt(j['used_points']),
        usd: asDouble(j['usd']),
        pointsPerUsd: asInt(j['points_per_usd'], 50),
        level: asInt(j['level'], 1),
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
  final String? socialNetwork;
  final String? socialAction;
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
    this.socialNetwork,
    this.socialAction,
    this.myStatus,
  });
  factory Task.fromJson(Map<String, dynamic> j) => Task(
        id: asInt(j['id']),
        title: j['title'] ?? '',
        description: j['description'] ?? '',
        instructions: j['instructions'] ?? '',
        category: j['category'] ?? 'otras',
        points: asInt(j['points']),
        estimatedMinutes: asInt(j['estimated_minutes'], 5),
        verification: j['verification'] ?? 'manual',
        requirements: j['requirements'] ?? '',
        targetUrl: j['target_url'] ?? '',
        socialNetwork: j['social_network'],
        socialAction: j['social_action'],
        myStatus: j['my_status'],
      );
  bool get isSocial => socialNetwork != null && socialNetwork!.isNotEmpty;
}

class TaskCompletion {
  final int id;
  final String status;
  final String? handle;
  final String? network;
  TaskCompletion({required this.id, required this.status, this.handle, this.network});
  factory TaskCompletion.fromJson(Map<String, dynamic> j) =>
      TaskCompletion(id: asInt(j['id']), status: j['status'] ?? 'pending', handle: j['handle'], network: j['network']);
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
        id: j['id'].toString(),
        type: j['type'],
        text: j['text'] ?? '',
        options:
            (j['options'] as List? ?? []).map((e) => e.toString()).toList(),
        required: j['required'] ?? false,
        min: asInt(j['min'], 1),
        max: asInt(j['max'], 5),
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
      id: asInt(s['id']),
      taskId: asInt(s['task_id']),
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
        threshold: asInt(j['threshold']),
        bonusPoints: asInt(j['bonus_points']),
        earned: asBool(j['earned']),
        progress: asInt(j['progress']),
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
        id: asInt(j['id']),
        points: asInt(j['points']),
        amountUsd: asDouble(j['amount_usd']),
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
        points: asInt(j['points']),
        balanceAfter: asInt(j['balance_after']),
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
  final int referenceId;
  SipiNotification(
      {required this.id,
      required this.type,
      required this.title,
      required this.body,
      required this.read,
      required this.createdAt,
      this.referenceId = 0});
  factory SipiNotification.fromJson(Map<String, dynamic> j) => SipiNotification(
        id: asInt(j['id']),
        type: j['type'] ?? '',
        title: j['title'] ?? '',
        body: j['body'] ?? '',
        read: asBool(j['is_read']),
        createdAt: j['created_at'] ?? '',
        referenceId: asInt(j['reference_id']),
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
