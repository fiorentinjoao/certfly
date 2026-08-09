import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/answer.dart';
import '../models/lesson.dart';
import '../models/lesson_summary.dart';
import '../models/me.dart';
import '../models/progress.dart';
import 'api_exception.dart';

/// Cliente HTTP dos 5 endpoints do MVP (docs/system-design.md). Todas as
/// rotas exigem `Authorization: Bearer <jwt_supabase>` — ver app/auth.py
/// no backend e lib/auth/auth_gateway.dart aqui (token de dev, sem Supabase
/// real ainda).
class ApiClient {
  final String baseUrl;
  final String token;
  final http.Client _http;

  ApiClient({required this.baseUrl, required this.token, http.Client? httpClient})
    : _http = httpClient ?? http.Client();

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Map<String, String> get _headers => {
    'Authorization': 'Bearer $token',
    'Content-Type': 'application/json',
  };

  Future<Map<String, dynamic>> _getJson(String path) async {
    final response = await _http.get(_uri(path), headers: _headers);
    return _decodeOrThrow(response);
  }

  Future<Map<String, dynamic>> _postJson(String path, {Object? body}) async {
    final response = await _http.post(
      _uri(path),
      headers: _headers,
      body: body == null ? null : jsonEncode(body),
    );
    return _decodeOrThrow(response);
  }

  Map<String, dynamic> _decodeOrThrow(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(response.statusCode, response.body);
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// GET /me — RF-01.
  Future<Me> getMe() async => Me.fromJson(await _getJson('/me'));

  /// GET /certification/{id}/progress — RF-02.
  Future<List<DomainProgress>> getCertificationProgress(String certificationId) async {
    final response = await _http.get(
      _uri('/certification/$certificationId/progress'),
      headers: _headers,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(response.statusCode, response.body);
    }
    final list = jsonDecode(response.body) as List;
    return list.map((d) => DomainProgress.fromJson(d as Map<String, dynamic>)).toList();
  }

  /// POST /topic/{id}/lesson — RF-03.
  Future<Lesson> startLesson(String topicId) async =>
      Lesson.fromJson(await _postJson('/topic/$topicId/lesson'));

  /// POST /question/{id}/answer — RF-04, RF-05, RF-07.
  Future<AnswerResult> answerQuestion(String questionId, String choiceId) async =>
      AnswerResult.fromJson(
        await _postJson('/question/$questionId/answer', body: {'choice_id': choiceId}),
      );

  /// POST /lesson-session/{id}/complete — RF-08, RF-09, RF-11.
  Future<LessonSummary> completeLessonSession(String sessionId) async => LessonSummary.fromJson(
    await _postJson('/lesson-session/$sessionId/complete'),
  );
}
