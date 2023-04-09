import 'package:flutter/material.dart';
import 'package:frc_8033_scouting_shared/frc_8033_scouting_shared.dart';
import 'package:scouting_dashboard_app/analysis_functions/alliance_analysis.dart';
import 'package:scouting_dashboard_app/datatypes.dart';
import 'package:scouting_dashboard_app/metrics.dart';
import 'package:scouting_dashboard_app/reusable/analysis_visualization.dart';
import 'package:scouting_dashboard_app/reusable/scrollable_page_body.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:scouting_dashboard_app/reusable/team_auto_paths.dart';

class AlliancePage extends StatefulWidget {
  const AlliancePage({super.key});

  @override
  State<AlliancePage> createState() => _AlliancePageState();
}

class _AlliancePageState extends State<AlliancePage> {
  @override
  Widget build(BuildContext context) {
    List<int> teams = (ModalRoute.of(context)!.settings.arguments
        as Map<String, dynamic>)['teams'];
    return Scaffold(
      appBar: AppBar(title: const Text("Alliance")),
      body: ScrollablePageBody(children: [
        AllianceVizualization(analysisFunction: AllianceAnalysis(teams: teams))
      ]),
    );
  }
}

class AllianceVizualization extends AnalysisVisualization {
  AllianceVizualization({required AllianceAnalysis super.analysisFunction});

  @override
  Widget loadedData(BuildContext context, AsyncSnapshot snapshot) {
    Map<String, dynamic> analysisMap = snapshot.data;

    return Column(children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: (analysisMap['teams'] as List<dynamic>)
            .map((teamData) => Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Tooltip(
                      message: teamData['role'] == null
                          ? "No data"
                          : RobotRole.values[teamData['role']].name,
                      child: Icon(teamData['role'] == null
                          ? Icons.question_mark
                          : RobotRole
                              .values[teamData['role'] as int].littleEmblem),
                    ),
                    const SizedBox(width: 3),
                    InkWell(
                      onTap: () => {
                        Navigator.of(context).pushNamed("/team_lookup",
                            arguments: <String, dynamic>{
                              'team': int.parse(teamData['team'].toString())
                            })
                      },
                      child: Text(
                        teamData['team'],
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ],
                ))
            .toList(),
      ),
      const SizedBox(height: 20),
      Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: const BorderRadius.all(Radius.circular(10)),
        ),
        padding: const EdgeInsets.all(10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Total points",
              style: Theme.of(context).textTheme.labelLarge!.merge(TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  )),
            ),
            Text(
              analysisMap['totalPoints'] == null
                  ? '--'
                  : numberVizualizationBuilder(
                      analysisMap['totalPoints'] as num),
              style: Theme.of(context).textTheme.titleLarge!.merge(TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  )),
            )
          ],
        ),
      ),
      const SizedBox(height: 10),
      if (analysisMap['levelCargo'] != null) cargoStack(context, analysisMap),
      const SizedBox(height: 10),
      AlllianceAutoPaths(data: analysisMap),
    ]);
  }
}

const autoPathColors = [
  Color(0xFF4255F9),
  Color(0xFF0D984D),
  Color(0xFFF95842),
];

class AlllianceAutoPaths extends StatefulWidget {
  const AlllianceAutoPaths({super.key, required this.data});

  final Map<String, dynamic> data;

  @override
  State<AlllianceAutoPaths> createState() => _AlllianceAutoPathsState();
}

class _AlllianceAutoPathsState extends State<AlllianceAutoPaths> {
  List<AutoPath?> selectedPaths = [
    null,
    null,
    null,
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: const BorderRadius.all(Radius.circular(10)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: widget.data['teams']
                      .map((e) => Column(
                            children: [
                              InkWell(
                                onTap: () {
                                  Navigator.of(context).pushNamed(
                                      "/auto_path_selector",
                                      arguments: <String, dynamic>{
                                        'team': e['team'],
                                        'autoPaths':
                                            (e['paths'] as List<dynamic>)
                                                .map((path) =>
                                                    AutoPath.fromMap(path))
                                                .toList(),
                                        'currentPath': selectedPaths[
                                            widget.data['teams'].indexOf(e)],
                                        'onSubmit': (AutoPath newPath) {
                                          setState(() {
                                            selectedPaths[widget.data['teams']
                                                .indexOf(e)] = newPath;
                                          });
                                        }
                                      });
                                },
                                child: Row(children: [
                                  SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: const BorderRadius.all(
                                            Radius.circular(10)),
                                        color: autoPathColors[
                                            widget.data['teams'].indexOf(e)],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    e['team'],
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium!
                                        .merge(
                                          TextStyle(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                        ),
                                  ),
                                ]),
                              ),
                              const SizedBox(height: 7),
                              Text(
                                "Score",
                                style: Theme.of(context)
                                    .textTheme
                                    .labelMedium!
                                    .merge(TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant)),
                              ),
                              Text(
                                selectedPaths[
                                            widget.data['teams'].indexOf(e)] ==
                                        null
                                    ? "--"
                                    : selectedPaths[
                                            widget.data['teams'].indexOf(e)]!
                                        .scores
                                        .join(", "),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyLarge!
                                    .merge(
                                      TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                                    ),
                              ),
                            ],
                          ))
                      .toList()
                      .cast<Widget>(),
                ),
                const SizedBox(height: 10),
                AutoPathField(
                  paths: selectedPaths
                      .where((e) => e != null)
                      .map((path) => AutoPathWidget(
                            autoPath: path!,
                            teamColor:
                                autoPathColors[selectedPaths.indexOf(path)],
                          ))
                      .toList(),
                ),
              ],
            ),
          ),
          Container(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Total auto score",
                    style: Theme.of(context).textTheme.labelLarge!.merge(
                        TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer)),
                  ),
                  Text(
                    selectedPaths.any((element) => element != null)
                        ? selectedPaths
                            .where((path) => path != null)
                            .map((path) =>
                                path!.scores.toList().cast<num>().average())
                            .toList()
                            .cast<num>()
                            .sum()
                            .toString()
                        : "--",
                    style: Theme.of(context).textTheme.bodyMedium!.merge(
                          TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer,
                          ),
                        ),
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}

Container cargoStack(
  BuildContext context,
  Map<String, dynamic> analysisMap, {
  Color? backgroundColor,
  Color? foregroundColor,
}) {
  int index = 0;

  return Container(
    decoration: BoxDecoration(
      color: backgroundColor ?? Theme.of(context).colorScheme.surfaceVariant,
      borderRadius: const BorderRadius.all(Radius.circular(10)),
    ),
    padding: const EdgeInsets.all(10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: (analysisMap['levelCargo'] as List<dynamic>)
          .map((row) {
            index++;
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  GridRow.values[index].localizedDescripton,
                  style:
                      Theme.of(context).textTheme.labelLarge!.merge(TextStyle(
                            color: foregroundColor ??
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          )),
                ),
                Row(
                  children: [
                    SizedBox(
                      width: 80,
                      child: Row(
                        children: [
                          SvgPicture.asset(
                            'assets/images/frc_cone.svg',
                            colorFilter: ColorFilter.mode(
                              foregroundColor ??
                                  Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                              BlendMode.srcIn,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            analysisMap['totalPoints'] == null
                                ? '--'
                                : numberVizualizationBuilder(
                                    row['cones'] as num),
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge!
                                .merge(TextStyle(
                                  color: foregroundColor ??
                                      Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                )),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 80,
                      child: Row(
                        children: [
                          SvgPicture.asset(
                            'assets/images/frc_cube.svg',
                            colorFilter: ColorFilter.mode(
                              foregroundColor ??
                                  Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                              BlendMode.srcIn,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            analysisMap['totalPoints'] == null
                                ? '--'
                                : numberVizualizationBuilder(
                                    row['cubes'] as num),
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge!
                                .merge(TextStyle(
                                  color: foregroundColor ??
                                      Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                )),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            );
          })
          .toList()
          .reversed
          .toList(),
    ),
  );
}
