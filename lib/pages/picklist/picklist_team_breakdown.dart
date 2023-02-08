import 'package:flutter/material.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:flutter/src/widgets/placeholder.dart';
import 'package:scouting_dashboard_app/constants.dart';
import 'package:scouting_dashboard_app/pages/picklist/picklist_models.dart';
import 'package:scouting_dashboard_app/reusable/page_body.dart';

class PicklistTeamBreakdownPage extends StatefulWidget {
  const PicklistTeamBreakdownPage({super.key});

  @override
  State<PicklistTeamBreakdownPage> createState() =>
      _PicklistTeamBreakdownPageState();
}

class _PicklistTeamBreakdownPageState extends State<PicklistTeamBreakdownPage> {
  bool useSameHeights = false;

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic> routeArgs =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;

    String teamNumber = routeArgs['team'].toString();
    String picklistTitle = routeArgs['picklistTitle'];
    List<Map<String, dynamic>> breakdown =
        routeArgs['breakdown'].cast<Map<String, dynamic>>();

    breakdown.sort((a, b) => (b['result'] as num).compareTo(a['result']));
    breakdown.removeWhere((e) => e['result'] == 0);

    return Scaffold(
      appBar: AppBar(
        title: Text("$teamNumber - $picklistTitle Picklist"),
        actions: [
          IconButton(
            onPressed: () => setState(() {
              useSameHeights = !useSameHeights;
            }),
            icon: Icon(useSameHeights ? Icons.expand : Icons.compress),
          ),
        ],
      ),
      body: PageBody(
          child: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(10)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: breakdown.map((weight) {
            bool alternate = (weight['result'] as num).isNegative
                ? breakdown.indexOf(weight).isOdd
                : breakdown.indexOf(weight).isEven;

            return Flexible(
              flex: useSameHeights
                  ? 1
                  : ((weight['result'] as num).abs() * 100).round(),
              child: Container(
                color: alternate
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.primaryContainer,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 10, right: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          picklistWeights
                              .firstWhere((e) => e.path == weight['type'],
                                  orElse: () => PicklistWeight(
                                      weight['type'], weight['type']))
                              .localizedName,
                          overflow: TextOverflow.clip,
                          style: Theme.of(context).textTheme.titleMedium!.merge(
                              TextStyle(
                                  color: alternate
                                      ? Theme.of(context).colorScheme.onPrimary
                                      : Theme.of(context)
                                          .colorScheme
                                          .onPrimaryContainer)),
                        ),
                        Text(
                          (weight['result'] as num).toStringAsFixed(2),
                          overflow: TextOverflow.clip,
                          style: Theme.of(context).textTheme.titleMedium!.merge(
                              TextStyle(
                                  color: alternate
                                      ? Theme.of(context).colorScheme.onPrimary
                                      : Theme.of(context)
                                          .colorScheme
                                          .onPrimaryContainer)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      )),
    );
  }
}
