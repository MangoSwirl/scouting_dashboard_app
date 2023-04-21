import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:scouting_dashboard_app/datatypes.dart';
import 'package:scouting_dashboard_app/pages/picklist/picklist_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

RegExp validServerAuthority = RegExp(
    "^((((?!-))(xn--)?[a-zA-Z0-9][a-zA-Z0-9-_]{0,61}[a-zA-Z0-9]{0,1}\\.(xn--)?([a-zA-Z0-9\\-]{1,61}|[a-zA-Z0-9-]{1,30}\\.[a-zA-Z]{2,}))|(localhost)|((25[0-5]|(2[0-4]|1\\d|[1-9]|)\\d)\\.?\\b){4})(:\\d+)?\$");

List<Tournament> tournamentList = <Tournament>[
  if (kDebugMode) Tournament("2022cc", "Chezy 2022 (debug)"),
  Tournament("2023week0", "2023 Week 0"),
  Tournament("2023cafr", "Fresno"),
  Tournament("2023camb", "Monterey"),
];

const List<ScoringMethod> scoringMethods = [
  ScoringMethod('coneOne', "L1 Cones"),
  ScoringMethod('coneTwo', "L2 Cones"),
  ScoringMethod('coneThree', "L3 Cones"),
  ScoringMethod('cubeOne', "L1 Cubes"),
  ScoringMethod('cubeTwo', "L2 Cubes"),
  ScoringMethod('cubeThree', "L3 Cubes"),
  ScoringMethod('climb', "Charge Station"),
];

// Picklists

final List<PicklistWeight> picklistWeights = [
  PicklistWeight('avgTotal', 'Average total'),
  PicklistWeight('defenseScore', 'Defense score'),
  PicklistWeight('driverAbility', 'Driver ability'),
  PicklistWeight('teleopScore', 'Teleop score'),
  PicklistWeight('coneOneScore', 'Cones L1'),
  PicklistWeight('coneTwoScore', 'Cones L2'),
  PicklistWeight('coneThreeScore', 'Cones L3'),
  PicklistWeight('cubeOneScore', 'Cubes L1'),
  PicklistWeight('cubeTwoScore', 'Cubes L2'),
  PicklistWeight('cubeThreeScore', 'Cubes L3'),
  PicklistWeight('feedCone', 'Cone feeder'),
  PicklistWeight('feedCube', 'Cube feeder'),
  PicklistWeight('autoCargo', 'Auto cargo'),
  PicklistWeight('autoClimb', 'Auto climb'),
  PicklistWeight('teleopClimb', 'Teleop climb'),
];

List<ConfiguredPicklist> defaultPicklists = <ConfiguredPicklist>[
  ConfiguredPicklist.autoUuid(
    "Average total",
    picklistWeights
        .map((weight) => PicklistWeight(weight.path, weight.localizedName,
            value: weight.path == 'avgTotal' ? 1 : 0))
        .toList(),
  ),
];

enum AutoPathPosition {
  none,
  grid1,
  grid2,
  grid3,
  grid4,
  grid5,
  grid6,
  grid7,
  grid8,
  grid9,
  crossedCable,
  crossedCharger,
  crossedNearBarrier,

  /// Farthest from the boundary that's near the cable protector
  prePlacedPiece1,

  /// 3rd closest to the boundary that's near the cable protector
  prePlacedPiece2,

  /// 2nd closest to the boundary that's near the cable protector
  prePlacedPiece3,

  /// Closest to the boundary that's near the cable protector
  prePlacedPiece4,

  startingTagId3,
  startingTagId2,
  startingTagId1,
}

final Map<AutoPathPosition, Offset> autoPositions = {
  AutoPathPosition.grid1: const Offset(263, 42),
  AutoPathPosition.grid2: const Offset(263, 108),
  AutoPathPosition.grid3: const Offset(263, 175),
  AutoPathPosition.grid4: const Offset(278, 42),
  AutoPathPosition.grid5: const Offset(278, 108),
  AutoPathPosition.grid6: const Offset(278, 175),
  AutoPathPosition.grid7: const Offset(297, 42),
  AutoPathPosition.grid8: const Offset(297, 108),
  AutoPathPosition.grid9: const Offset(297, 175),
  AutoPathPosition.crossedCable: const Offset(157, 186),
  AutoPathPosition.crossedCharger: const Offset(157, 109),
  AutoPathPosition.crossedNearBarrier: const Offset(178, 32),
  AutoPathPosition.prePlacedPiece1: const Offset(32, 35),
  AutoPathPosition.prePlacedPiece2: const Offset(32, 83),
  AutoPathPosition.prePlacedPiece3: const Offset(32, 131),
  AutoPathPosition.prePlacedPiece4: const Offset(32, 179),
  AutoPathPosition.startingTagId3: const Offset(200, 42),
  AutoPathPosition.startingTagId2: const Offset(200, 108),
  AutoPathPosition.startingTagId1: const Offset(200, 175),
};

Tournament? getTournamentByKey(String key) {
  try {
    return tournamentList.firstWhere((tournament) => tournament.key == key);
  } on StateError {
    return null;
  }
}

Future<String?> getServerAuthority() async {
  final prefs = await SharedPreferences.getInstance();

  return prefs.getString("serverAuthority");
}
