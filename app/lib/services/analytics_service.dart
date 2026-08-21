import '../models/analytics.dart';
import 'api_client.dart';
import 'public_api_client.dart';

enum RankingScope { classScope, parallel, school }

class AnalyticsService {
  AnalyticsService(this._apiClient, this._publicApiClient);

  final ApiClient _apiClient;
  final PublicApiClient _publicApiClient;

  /// `parentId` routes the request through the Public Server, same as
  /// grades/attendance (see JournalService.listGrades) -- a parent's app
  /// never talks to the local school-network server directly.
  Future<StudentAnalyticsOverview> studentOverview({
    required int studentId,
    int? quarter,
    int? parentId,
    bool viaPublicServer = false,
  }) async {
    final client = (parentId != null || viaPublicServer) ? _publicApiClient : _apiClient;
    final data = await client.get(
      '/analytics/student/$studentId',
      query: {if (quarter != null) 'quarter': quarter.toString()},
    ) as Map<String, dynamic>;
    return StudentAnalyticsOverview.fromJson(data);
  }

  /// Ranking leaderboards are director/teacher-only (local server) -- there
  /// is no Public Server equivalent, since a parent only ever sees their own
  /// child's rank via [studentOverview], not the full roster.
  Future<List<LeaderboardEntry>> ranking({
    required RankingScope scope,
    int? scopeId,
    int? quarter,
  }) async {
    final path = switch (scope) {
      RankingScope.classScope => '/analytics/class/$scopeId/ranking',
      RankingScope.parallel => '/analytics/parallel/$scopeId/ranking',
      RankingScope.school => '/analytics/school/ranking',
    };
    final data = await _apiClient.get(
      path,
      query: {if (quarter != null) 'quarter': quarter.toString()},
    ) as List<dynamic>;
    return data
        .map((e) => LeaderboardEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Which subjects a class is strong and weak in, strongest first.
  ///
  /// Local server only, like [ranking]: it describes a whole class, which is
  /// staff information -- nothing a parent or pupil is shown needs it.
  Future<List<ClassSubjectAverage>> classSubjects({
    required int classId,
    int? quarter,
  }) async {
    final data = await _apiClient.get(
      '/analytics/class/$classId/subjects',
      query: {if (quarter != null) 'quarter': quarter.toString()},
    ) as List<dynamic>;
    return data
        .map((e) => ClassSubjectAverage.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Bottom performers + biggest quarter-over-quarter decliners for a class
  /// or the whole school -- director/teacher only, same as [ranking].
  Future<NeedsAttentionResult> needsAttention({
    required RankingScope scope,
    int? scopeId,
    int? quarter,
  }) async {
    final path = switch (scope) {
      RankingScope.classScope => '/analytics/class/$scopeId/needs-attention',
      RankingScope.school => '/analytics/school/needs-attention',
      RankingScope.parallel => throw UnsupportedError('Needs-attention has no parallel scope'),
    };
    final data = await _apiClient.get(
      path,
      query: {if (quarter != null) 'quarter': quarter.toString()},
    ) as Map<String, dynamic>;
    return NeedsAttentionResult.fromJson(data);
  }
}
