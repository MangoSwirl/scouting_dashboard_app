import 'dart:convert';

import 'package:auth0_flutter/auth0_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:frc_8033_scouting_shared/frc_8033_scouting_shared.dart';
import 'package:http/http.dart' as http;
import 'package:scouting_dashboard_app/constants.dart';
import 'package:scouting_dashboard_app/datatypes.dart';
import 'package:scouting_dashboard_app/pages/match_schedule.dart';
import 'package:scouting_dashboard_app/pages/picklist/picklist_models.dart';
import 'package:scouting_dashboard_app/pages/raw_scout_report.dart';
import 'package:scouting_dashboard_app/reusable/lovat_api/promote_analyst.dart';
import 'package:scouting_dashboard_app/reusable/models/team.dart';
import 'package:scouting_dashboard_app/reusable/team_auto_paths.dart';
import 'package:uuid/uuid.dart';

class LovatAPI {
  LovatAPI(this.baseUrl);

  final String baseUrl;
  bool isAuthenticating = false;

  Future<Credentials> login() async {
    if (isAuthenticating) {
      // Wait for the current login to finish
      while (isAuthenticating) {
        await Future.delayed(const Duration(milliseconds: 100));
      }

      return await auth0.credentialsManager.credentials();
    }

    isAuthenticating = true;

    try {
      final newCredentials = await auth0
          .webAuthentication(scheme: "com.frc8033.lovatdashboard")
          .login(
            audience: "https://api.lovat.app",
          );

      await auth0.credentialsManager.storeCredentials(newCredentials);

      return newCredentials;
    } finally {
      isAuthenticating = false;
    }
  }

  Future<String?> getAccessToken() async {
    try {
      final credentials = await auth0.credentialsManager.credentials();

      if (credentials.expiresAt.isBefore(DateTime.now())) {
        if (credentials.refreshToken == null) {
          return (await login()).accessToken;
        }

        final newCredentials = await auth0.api
            .renewCredentials(refreshToken: credentials.accessToken);

        await auth0.credentialsManager.storeCredentials(newCredentials);

        return newCredentials.accessToken;
      } else {
        return credentials.accessToken;
      }
    } on CredentialsManagerException {
      return (await login()).accessToken;
    }
  }

  Future<http.Response?> get(String path, {Map<String, String>? query}) async {
    final token = await getAccessToken();

    debugPrint(token);

    final uri = Uri.parse(baseUrl + path).replace(queryParameters: query);

    return await http.get(uri, headers: {
      if (token != null) 'Authorization': 'Bearer $token',
    });
  }

  Future<http.Response?> post(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
  }) async {
    final token = await getAccessToken();

    final uri = Uri.parse(baseUrl + path).replace(queryParameters: query);

    return await http
        .post(uri, body: body != null ? jsonEncode(body) : null, headers: {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    });
  }

  Future<http.Response?> put(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
  }) async {
    final token = await getAccessToken();

    final uri = Uri.parse(baseUrl + path).replace(queryParameters: query);

    return await http
        .put(uri, body: body != null ? jsonEncode(body) : null, headers: {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    });
  }

  Future<http.Response?> delete(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
  }) async {
    final token = await getAccessToken();

    final uri = Uri.parse(baseUrl + path).replace(queryParameters: query);

    return await http
        .delete(uri, body: body != null ? jsonEncode(body) : null, headers: {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    });
  }

  // MARK: Endpoints

  Future<List<MatchScheduleMatch>> getMatches(
    String tournamentKey, {
    bool? isScouted,
    List<int>? teamNumbers,
  }) async {
    final response = await get(
      "/v1/manager/matches/$tournamentKey",
      query: {
        if (isScouted != null) 'isScouted': isScouted.toString(),
        if (teamNumbers != null) 'teams': jsonEncode(teamNumbers),
      },
    );

    if (response?.statusCode == 404) {
      throw const LovatAPIException(
          'No matches found. This is likely because the match schedule has not been posted on The Blue Alliance yet. Please try again later.');
    }

    if (response?.body ==
        'tournament not found when trying to insert tournament matches') {
      throw const LovatAPIException('Tournament not found');
    }

    if (response?.statusCode != 200) {
      debugPrint(response?.body ?? '');

      try {
        throw LovatAPIException(jsonDecode(response!.body)['displayError']);
      } on LovatAPIException {
        rethrow;
      } catch (_) {
        throw Exception('Failed to get match schedule');
      }
    }

    final json = jsonDecode(response!.body) as List<dynamic>;

    debugPrint(response.body);

    return json.map((e) => MatchScheduleMatch.fromJson(e)).toList();
  }

  Future<List<Team>> getTeamsAtTournament(String tournamentKey) async {
    final response = await get("/v1/manager/tournament/$tournamentKey/teams");

    if (response?.statusCode != 200) {
      debugPrint(response?.body ?? '');
      throw Exception('Failed to get teams at tournament');
    }

    final json = jsonDecode(response!.body) as List<dynamic>;

    return json.map((e) => Team.fromJson(e)).toList();
  }

  Future<SingleScoutReportAnalysis> getScoutReportAnalysis(
    String reportId,
  ) async {
    final response = await get('/v1/analysis/metrics/scoutreport/$reportId');
    debugPrint(response?.body ?? '');

    if (response?.statusCode != 200) {
      debugPrint(response?.body ?? '');
      throw Exception('Failed to get scout report analysis');
    }

    return SingleScoutReportAnalysis.fromJson(jsonDecode(response!.body));
  }

  Future<List<ScoutReportEvent>> getEventsForScoutReport(
    String reportId,
  ) async {
    final response = await get('/v1/analysis/timeline/scoutreport/$reportId');

    if (response?.statusCode != 200) {
      debugPrint(response?.body ?? '');
      throw Exception('Failed to get events for scout report');
    }

    final json = jsonDecode(response!.body) as List<dynamic>;

    return json
        .map((e) => ScoutReportEvent.fromList((e as List<dynamic>).cast<int>()))
        .toList();
  }

  Future<void> updateNote(String noteUuid, String newBody) async {
    final response = await put(
      '/v1/manager/notes/$noteUuid',
      body: {
        'note': newBody,
      },
    );

    debugPrint(response?.body ?? '');

    if (response?.statusCode != 200) {
      throw Exception('Failed to update note');
    }
  }

  Future<void> deleteScoutReport(String reportId) async {
    final response = await delete('/v1/manager/scoutreports/$reportId');

    if (response?.statusCode != 200) {
      debugPrint(response?.body ?? '');
      throw Exception('Failed to delete scout report');
    }
  }

  Future<List<dynamic>> getFlags(List<String> paths, int teamNumber) async {
    final tournament = await Tournament.getCurrent();

    final response = await get(
      '/v1/analysis/flag/team/$teamNumber',
      query: {
        if (tournament != null) 'tournamentKey': tournament.key,
        'flags': jsonEncode(paths),
      },
    );

    if (response?.statusCode != 200) {
      throw Exception('Failed to get flags');
    }

    return jsonDecode(response!.body) as List<dynamic>;
  }

  Future<dynamic> getFlag(path, teamNumber) async {
    return (await getFlags([path], teamNumber)).first;
  }

  Future<void> editTeamEmail(String newEmail) async {
    final response = await lovatAPI.put(
      '/v1/manager/settings/teamemail',
      query: {
        'email': newEmail,
      },
    );

    if (response?.statusCode != 200) {
      debugPrint(response?.body ?? '');
      try {
        throw LovatAPIException(jsonDecode(response!.body)['displayError']);
      } on LovatAPIException {
        rethrow;
      } catch (_) {
        throw Exception('Failed to edit team email');
      }
    }
  }

  Future<void> setNotOnTeam() async {
    final response = await lovatAPI.post('/v1/manager/noteam');

    if (response?.statusCode != 200) {
      debugPrint(response?.body ?? '');
      try {
        throw LovatAPIException(jsonDecode(response!.body)['displayError']);
      } on LovatAPIException {
        rethrow;
      } catch (_) {
        throw Exception('Failed to set not on team');
      }
    }
  }

  Future<List<ScouterOverview>> getScouterOverviews() async {
    final tournament = await Tournament.getCurrent();

    final response = await lovatAPI.get(
      '/v1/manager/scouterspage',
      query: {
        if (tournament != null) 'tournamentKey': tournament.key,
      },
    );

    if (response?.statusCode != 200) {
      try {
        throw LovatAPIException(jsonDecode(response!.body)['displayError']);
      } on LovatAPIException {
        rethrow;
      } catch (_) {
        throw Exception('Failed to get scouter overviews');
      }
    }

    final json = jsonDecode(response!.body) as List<dynamic>;

    return json.map((e) => ScouterOverview.fromJson(e)).toList();
  }

  Future<void> addScouter(String name) async {
    final response = await lovatAPI.post(
      '/v1/manager/scouterdashboard',
      body: {
        'name': name,
      },
    );

    if (response?.statusCode != 200) {
      try {
        throw LovatAPIException(jsonDecode(response!.body)['displayError']);
      } on LovatAPIException {
        rethrow;
      } catch (_) {
        throw Exception('Failed to add scouter');
      }
    }
  }

  Future<void> deleteScouter(String id) async {
    final response = await lovatAPI.delete(
      '/v1/manager/scouterdashboard',
      body: {
        'scouterUuid': id,
      },
    );

    if (response?.statusCode != 200) {
      try {
        throw LovatAPIException(jsonDecode(response!.body)['displayError']);
      } on LovatAPIException {
        rethrow;
      } catch (_) {
        throw Exception('Failed to delete scouter');
      }
    }
  }

  Future<void> renameScouter(String id, String newName) async {
    final response = await lovatAPI.put(
      '/v1/manager/scoutername',
      body: {
        'scouterUuid': id,
        'newName': newName,
      },
    );

    if (response?.statusCode != 200) {
      try {
        throw LovatAPIException(jsonDecode(response!.body)['displayError']);
      } on LovatAPIException {
        rethrow;
      } catch (_) {
        throw Exception('Failed to rename scouter');
      }
    }
  }

  Future<List<ScouterPageMinimalScoutReportInfo>> getScoutReportsByScouter(
    String scouterId,
  ) async {
    final tournament = await Tournament.getCurrent();

    final response = await lovatAPI.get(
      '/v1/manager/scouterreports',
      query: {
        'scouterUuid': scouterId,
        if (tournament != null) 'tournamentKey': tournament.key,
      },
    );

    if (response?.statusCode != 200) {
      try {
        throw LovatAPIException(jsonDecode(response!.body)['displayError']);
      } on LovatAPIException {
        rethrow;
      } catch (_) {
        throw Exception('Failed to get scout reports by scouter');
      }
    }

    final json = jsonDecode(response!.body) as List<dynamic>;

    return json
        .map((e) => ScouterPageMinimalScoutReportInfo.fromJson(e))
        .toList();
  }

  Future<String> getCSVExport(Tournament tournament, CSVExportMode mode) async {
    final response = await lovatAPI.get(
      '/v1/analysis/${mode.slug}',
      query: {
        'tournamentKey': tournament.key,
      },
    );

    if (response?.statusCode != 200) {
      try {
        throw LovatAPIException(jsonDecode(response!.body)['displayError']);
      } on LovatAPIException {
        rethrow;
      } catch (_) {
        throw Exception('Failed to get CSV export');
      }
    }

    return response!.body;
  }
}

class LovatAPIException implements Exception {
  const LovatAPIException(this.message);

  final String message;

  @override
  String toString() => message;
}

enum CSVExportMode {
  byTeam,
  byScoutReport,
}

extension CSVExportModeExtension on CSVExportMode {
  String get slug {
    switch (this) {
      case CSVExportMode.byTeam:
        return 'csvplain';
      case CSVExportMode.byScoutReport:
        return 'reportcsv';
    }
  }

  String get localizedDescription {
    switch (this) {
      case CSVExportMode.byTeam:
        return 'By team';
      case CSVExportMode.byScoutReport:
        return 'By scout report';
    }
  }

  String get longLocalizedDescription {
    switch (this) {
      case CSVExportMode.byTeam:
        return 'Each row contains a team\'s aggregated statistics throughout the tournament.';
      case CSVExportMode.byScoutReport:
        return 'Each row contains data collected by one scouter about a specific team\'s performance during a match.';
    }
  }
}

class Analyst {
  const Analyst({
    required this.id,
    required this.name,
    required this.email,
  });

  final String id;
  final String name;
  final String email;

  factory Analyst.fromJson(Map<String, dynamic> json) => Analyst(
        id: json['id'] as String,
        name: json['username'] as String,
        email: json['email'] as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': name,
        'email': email,
      };

  Future<void> promote() async {
    await lovatAPI.promoteAnalyst(id);
  }
}

class MatchScheduleMatch {
  const MatchScheduleMatch({
    required this.identity,
    required this.isScouted,
    required this.red1,
    required this.red2,
    required this.red3,
    required this.blue1,
    required this.blue2,
    required this.blue3,
  });

  final GameMatchIdentity identity;

  final MatchScheduleTeamInfo red1;
  final MatchScheduleTeamInfo red2;
  final MatchScheduleTeamInfo red3;
  final MatchScheduleTeamInfo blue1;
  final MatchScheduleTeamInfo blue2;
  final MatchScheduleTeamInfo blue3;

  final bool isScouted;

  List<MatchScheduleTeamInfo> get allTeamInfo => [
        red1,
        red2,
        red3,
        blue1,
        blue2,
        blue3,
      ];

  factory MatchScheduleMatch.fromJson(Map<String, dynamic> json) {
    return MatchScheduleMatch(
      identity: GameMatchIdentity(MatchType.values[json['matchType']],
          json['matchNumber'], json['tournamentKey']),
      isScouted: json['scouted'],
      red1: MatchScheduleTeamInfo.fromJson(json['team1']),
      red2: MatchScheduleTeamInfo.fromJson(json['team2']),
      red3: MatchScheduleTeamInfo.fromJson(json['team3']),
      blue1: MatchScheduleTeamInfo.fromJson(json['team4']),
      blue2: MatchScheduleTeamInfo.fromJson(json['team5']),
      blue3: MatchScheduleTeamInfo.fromJson(json['team6']),
    );
  }
}

class MatchScheduleTeamInfo {
  const MatchScheduleTeamInfo({
    required this.teamNumber,
    required this.alliance,
    required this.scouters,
    required this.externalReportCount,
  });

  final int teamNumber;
  final Alliance alliance;
  final List<MatchScheduleScouterInfo> scouters;
  final int externalReportCount;

  factory MatchScheduleTeamInfo.fromJson(Map<String, dynamic> json) {
    return MatchScheduleTeamInfo(
      teamNumber: json['number'],
      alliance: AllianceExtension.fromString(json['alliance']),
      scouters: (json['scouters'] as List<dynamic>)
          .map((e) => MatchScheduleScouterInfo.fromJson(e))
          .toList(),
      externalReportCount: json['externalReports'],
    );
  }
}

class MatchScheduleScouterInfo {
  const MatchScheduleScouterInfo({
    required this.name,
    required this.isScouted,
  });

  final String name;
  final bool isScouted;

  factory MatchScheduleScouterInfo.fromJson(Map<String, dynamic> json) {
    return MatchScheduleScouterInfo(
      name: json['name'],
      isScouted: json['scouted'],
    );
  }
}

class MinimalScoutReportInfo {
  const MinimalScoutReportInfo({
    required this.uuid,
    required this.scout,
    required this.timestamp,
  });

  final String uuid;
  final Scout scout;
  final DateTime timestamp;

  factory MinimalScoutReportInfo.fromJson(Map<String, dynamic> json) {
    return MinimalScoutReportInfo(
      uuid: json['uuid'],
      scout: Scout(
        id: json['scouterUuid'],
        name: json['scouter']['name'],
      ),
      timestamp: DateTime.parse(json['startTime']),
    );
  }
}

class ScouterPageMinimalScoutReportInfo {
  const ScouterPageMinimalScoutReportInfo({
    required this.matchIdentity,
    required this.reportId,
    required this.teamNumber,
  });

  final GameMatchIdentity matchIdentity;
  final String reportId;
  final int teamNumber;

  factory ScouterPageMinimalScoutReportInfo.fromJson(
      Map<String, dynamic> json) {
    return ScouterPageMinimalScoutReportInfo(
      matchIdentity: GameMatchIdentity.fromLongKey(
        json['teamMatchData']['key'],
        tournamentName: json['teamMatchData']['tournament']['name'],
      ),
      reportId: json['uuid'],
      teamNumber: json['teamMatchData']['teamNumber'],
    );
  }
}

class SingleScoutReportAnalysis {
  const SingleScoutReportAnalysis({
    required this.totalPoints,
    required this.driverAbility,
    required this.robotRole,
    required this.defense,
    required this.ampScores,
    required this.speakerScores,
    required this.trapScores,
    required this.pickups,
    required this.autoPath,
    required this.stageResult,
    required this.highNoteResult,
    this.notes,
  });

  final int totalPoints;
  final DriverAbility driverAbility;
  final RobotRole robotRole;
  final int defense;
  final int ampScores;
  final int speakerScores;
  final int trapScores;
  final int pickups;
  final AutoPath autoPath;
  final String? notes;
  final StageResult stageResult;
  final HighNoteResult highNoteResult;

  factory SingleScoutReportAnalysis.fromJson(Map<String, dynamic> json) {
    return SingleScoutReportAnalysis(
      totalPoints: json['totalPoints'],
      driverAbility: DriverAbility.values[(json['driverAbility'] as int) - 1],
      robotRole: RobotRole.values[json['role']],
      defense: json['defense'],
      ampScores: json['ampscores'],
      speakerScores: json['speakerscores'],
      trapScores: json['trapscores'],
      pickups: json['pickups'],
      autoPath: AutoPath.fromMapSingleMatch(json['autoPath']),
      notes: (json['note'] as String).isEmpty ? null : json['note'],
      stageResult: StageResult.values[json['stage']],
      highNoteResult: HighNoteResult.values[json['highNote']],
    );
  }
}

class ScouterOverview {
  const ScouterOverview({
    required this.totalMatches,
    required this.missedMatches,
    required this.scout,
  });

  final int totalMatches;
  final int missedMatches;
  final Scout scout;

  factory ScouterOverview.fromJson(Map<String, dynamic> json) {
    return ScouterOverview(
      totalMatches: json['matchesScouted'],
      missedMatches: json['missedMatches'] ?? 0,
      scout: Scout(
        id: json['scouterUuid'],
        name: json['scouterName'],
      ),
    );
  }
}

final lovatAPI = LovatAPI("https://api.lovat.app");
