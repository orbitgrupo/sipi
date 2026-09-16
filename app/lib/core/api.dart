// Sipi — cliente HTTP de la API. El servidor calcula todos los montos;
// la app nunca inventa cantidades de puntos.
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models.dart';

class ApiException implements Exception {
  final int status;
  final String code;
  ApiException(this.status, this.code);
  @override
  String toString() => 'ApiException($status, $code)';

  static String friendly(String code) {
    switch (code) {
      case 'EMAIL_TAKEN':
        return 'Ese correo ya está registrado.';
      case 'INVALID_CREDENTIALS':
        return 'Correo o contraseña incorrectos.';
      case 'WEAK_PASSWORD':
        return 'La contraseña debe tener al menos 6 caracteres.';
      case 'INSUFFICIENT_POINTS':
        return 'No tienes puntos suficientes.';
      case 'TASK_LIMIT_REACHED':
        return 'Ya completaste esta tarea.';
      case 'ALREADY_PENDING':
        return 'Ya enviaste esta tarea, está en revisión.';
      case 'SURVEY_ALREADY_ANSWERED':
        return 'Ya respondiste esta encuesta.';
      case 'AMOUNT_TOO_LOW':
        return 'El monto es demasiado bajo.';
      case 'INVALID_EMAIL':
        return 'Ese correo electrónico no es válido.';
      default:
        return 'Ocurrió un error. Inténtalo de nuevo.';
    }
  }
}

class SipiApi {
  final String baseUrl;
  String? token;
  SipiApi({this.baseUrl = 'http://10.0.2.2:3000'});

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Future<dynamic> _req(String method, String path,
      [Map<String, dynamic>? body]) async {
    final uri = Uri.parse('$baseUrl$path');
    final http.Response r;
    if (method == 'GET') {
      r = await http.get(uri, headers: _headers);
    } else if (method == 'POST') {
      r = await http.post(uri, headers: _headers, body: jsonEncode(body ?? {}));
    } else if (method == 'PUT') {
      r = await http.put(uri, headers: _headers, body: jsonEncode(body ?? {}));
    } else {
      throw UnsupportedError(method);
    }
    if (r.statusCode >= 400) {
      String code = 'ERROR';
      try {
        code = jsonDecode(r.body)['error'] ?? code;
      } catch (_) {}
      throw ApiException(r.statusCode, code);
    }
    if (r.body.isEmpty) return {};
    return jsonDecode(r.body);
  }

  // ---- Auth ----
  Future<({User user, String token})> register(
      String name, String email, String password) async {
    final j = await _req('POST', '/api/auth/register',
        {'name': name, 'email': email, 'password': password});
    token = j['token'];
    return (user: User.fromJson(j['user']), token: j['token'] as String);
  }

  Future<({User user, String token})> login(
      String email, String password) async {
    final j = await _req(
        'POST', '/api/auth/login', {'email': email, 'password': password});
    token = j['token'];
    return (user: User.fromJson(j['user']), token: j['token'] as String);
  }

  Future<User> me() async {
    final j = await _req('GET', '/api/auth/me');
    return User.fromJson(j['user']);
  }

  Future<User> updateProfile({required String name, required String email}) async {
    final j = await _req(
        'PUT', '/api/users/me', {'name': name, 'email': email});
    return User.fromJson(j['user']);
  }

  Future<void> changePassword(
      {required String currentPassword, required String newPassword}) async {
    await _req('PUT', '/api/users/me/password', {
      'current_password': currentPassword,
      'new_password': newPassword,
    });
  }

  // ---- Saldo ----
  Future<Balance> balance() async =>
      Balance.fromJson(await _req('GET', '/api/balance'));
  Future<List<LedgerMovement>> ledger() async =>
      ((await _req('GET', '/api/ledger'))['movements'] as List)
          .map((e) => LedgerMovement.fromJson(e))
          .toList();

  // ---- Tareas ----
  Future<List<Task>> tasks({String? category, String? q}) async {
    final params = <String, String>{};
    if (category != null && category != 'todas') params['category'] = category;
    if (q != null && q.isNotEmpty) params['q'] = q;
    final query = params.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
        .join('&');
    final j = await _req('GET', '/api/tasks${query.isEmpty ? '' : '?$query'}');
    return (j['tasks'] as List).map((e) => Task.fromJson(e)).toList();
  }

  Future<({Task task, List<TaskCompletion> mine})> taskDetail(int id) async {
    final j = await _req('GET', '/api/tasks/$id');
    return (
      task: Task.fromJson(j['task']),
      mine: ((j['my_completions'] as List?) ?? [])
          .map((e) => TaskCompletion.fromJson(e))
          .toList(),
    );
  }

  Future<TaskCompletion> submitTask(int id, {String evidence = ''}) async {
    final j =
        await _req('POST', '/api/tasks/$id/submit', {'evidence': evidence});
    return TaskCompletion.fromJson(j['completion']);
  }

  // ---- Encuestas ----
  Future<Survey> survey(int taskId) async =>
      Survey.fromJson(await _req('GET', '/api/tasks/$taskId/survey'));

  Future<Map<String, dynamic>> answerSurvey(
      int taskId, Map<String, dynamic> answers) async {
    final j =
        await _req('POST', '/api/tasks/$taskId/survey', {'answers': answers});
    return Map<String, dynamic>.from(j);
  }

  // ---- Canjes ----
  Future<Redemption> redeem(int points) async =>
      Redemption.fromJson((await _req(
          'POST', '/api/redemptions', {'points': points}))['redemption']);
  Future<List<Redemption>> redemptions() async =>
      ((await _req('GET', '/api/redemptions'))['redemptions'] as List)
          .map((e) => Redemption.fromJson(e))
          .toList();

  // ---- Logros / notificaciones ----
  Future<List<Achievement>> achievements() async =>
      ((await _req('GET', '/api/achievements'))['achievements'] as List)
          .map((e) => Achievement.fromJson(e))
          .toList();
  Future<List<SipiNotification>> notifications() async =>
      ((await _req('GET', '/api/notifications'))['notifications'] as List)
          .map((e) => SipiNotification.fromJson(e))
          .toList();
  Future<void> markNotificationRead(int id) async =>
      _req('POST', '/api/notifications/$id/read');
}
