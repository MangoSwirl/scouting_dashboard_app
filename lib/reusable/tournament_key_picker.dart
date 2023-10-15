import 'dart:convert';

import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:scouting_dashboard_app/constants.dart';
import 'package:scouting_dashboard_app/datatypes.dart';

import 'package:http/http.dart' as http;
import 'package:scouting_dashboard_app/pages/custom_tournament.dart';
import 'package:scouting_dashboard_app/reusable/push_widget_extension.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skeletons/skeletons.dart';

class TournamentKeyPicker extends StatefulWidget {
  const TournamentKeyPicker({
    super.key,
    this.decoration,
    required this.onChanged,
    this.initialValue,
  });

  final InputDecoration? decoration;
  final dynamic Function(Tournament) onChanged;
  final Tournament? initialValue;

  @override
  State<TournamentKeyPicker> createState() => _TournamentKeyPickerState();
}

class _TournamentKeyPickerState extends State<TournamentKeyPicker> {
  List<Tournament> tournaments = [];
  bool isScoutingLead = false;
  bool hasError = false;

  bool initialized = false;
  Tournament? selectedItem;

  Future<void> getTournaments() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      isScoutingLead = prefs.getString('role') == '8033_scouting_lead';
    });

    late final http.Response response;

    try {
      response = await http.get(Uri.http(
          (await getServerAuthority())!, '/API/manager/getTournaments'));
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          "Error getting tournaments: $error",
          style: TextStyle(
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.errorContainer,
        behavior: SnackBarBehavior.floating,
      ));

      setState(() {
        hasError = true;
      });

      return;
    }

    if (response.statusCode != 200) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          "Error getting tournaments: ${response.statusCode} ${response.reasonPhrase} ${response.body}",
          style: TextStyle(
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.errorContainer,
        behavior: SnackBarBehavior.floating,
      ));

      setState(() {
        hasError = true;
      });

      return;
    }

    List<Map<String, dynamic>> responseList =
        jsonDecode(response.body).cast<Map<String, dynamic>>();

    setState(() {
      tournaments = responseList
          .map((e) => Tournament(e['key'],
              "${RegExp("^\\d+").stringMatch(e['key'] as String)!} ${e['name']}"))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (tournaments.isEmpty && !hasError) getTournaments();

    if (!initialized) {
      setState(() {
        selectedItem = widget.initialValue;

        initialized = true;
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        (tournaments.isEmpty && !hasError)
            ? LayoutBuilder(builder: (context, constraints) {
                return SkeletonAvatar(
                  style: SkeletonAvatarStyle(
                      height: 56,
                      width: constraints.maxWidth,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(4),
                        topRight: Radius.circular(4),
                        bottomLeft: Radius.circular(0),
                        bottomRight: Radius.circular(0),
                      )),
                );
              })
            : DropdownSearch<Tournament>(
                onChanged: (value) {
                  setState(() {
                    selectedItem = value;
                  });
                  widget.onChanged(value!);
                },
                itemAsString: (item) => item.localized,
                items: tournaments,
                dropdownDecoratorProps: DropDownDecoratorProps(
                  dropdownSearchDecoration: widget.decoration,
                ),
                selectedItem: selectedItem,
                popupProps: PopupProps.modalBottomSheet(
                  constraints: const BoxConstraints.expand(),
                  modalBottomSheetProps: ModalBottomSheetProps(
                    backgroundColor:
                        Theme.of(context).colorScheme.surfaceVariant,
                  ),
                  emptyBuilder: (context, searchEntry) {
                    return SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              "Your query doesn't match any tournaments on The\u{00A0}Blue\u{00A0}Alliance.",
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 5),
                            Text(
                              "If you're at a tournament that doesn't publish a match schedule to FIRST or The\u{00A0}Blue\u{00A0}Alliance, ${isScoutingLead ? 'you' : 'a scouting lead'} can add a custom tournament.",
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                            const SizedBox(height: 20),
                            if (isScoutingLead)
                              FilledButton(
                                onPressed: () {
                                  final thisRoute = ModalRoute.of(context);

                                  Navigator.of(context).pushWidget(
                                    CustomTournamentPage(
                                      initialName: searchEntry,
                                      tournaments: tournaments,
                                      onCreate: (value) {
                                        getTournaments();

                                        setState(() {
                                          selectedItem = value;
                                        });
                                        widget.onChanged(value);

                                        Navigator.of(context).pop();
                                        Navigator.of(context).pop();
                                      },
                                    ),
                                  );
                                },
                                child: const Text("Create one"),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                  fit: FlexFit.loose,
                  showSearchBox: true,
                  searchFieldProps: const TextFieldProps(
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      label: Text("Search"),
                    ),
                  ),
                  containerBuilder: (context, popupWidget) => SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 20),
                      child: Stack(children: [
                        Column(children: [
                          const SizedBox(height: 40),
                          Expanded(child: popupWidget),
                        ]),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.expand_more),
                            tooltip: "Close",
                            visualDensity: VisualDensity.comfortable,
                          ),
                        )
                      ]),
                    ),
                  ),
                  searchDelay: Duration.zero,
                ),
              ),
        if (hasError) ...[
          const SizedBox(height: 10),
          FilledButton(
              onPressed: () {
                showDialog(
                    context: context,
                    builder: (context) => ManualTournamentInputDialog(
                          onSubmit: widget.onChanged,
                        ));
              },
              child: const Text("Enter manually")),
        ],
      ],
    );
  }
}

class ManualTournamentInputDialog extends StatefulWidget {
  const ManualTournamentInputDialog({
    super.key,
    required this.onSubmit,
  });

  final dynamic Function(Tournament) onSubmit;

  @override
  State<ManualTournamentInputDialog> createState() =>
      _ManualTournamentInputDialogState();
}

class _ManualTournamentInputDialogState
    extends State<ManualTournamentInputDialog> {
  String name = "";
  String key = "";

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              onChanged: (value) => setState(() {
                name = value;
              }),
              decoration: const InputDecoration(
                filled: true,
                label: Text("Name"),
                helperText: "Only used visually",
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              onChanged: (value) => setState(() {
                key = value;
              }),
              decoration: InputDecoration(
                  filled: true,
                  label: const Text("Key"),
                  errorText: RegExp("^\\d+.+\$").hasMatch(key) || key.isEmpty
                      ? null
                      : "Must include the year, i.e. 2023cafr"),
            ),
            const SizedBox(height: 60),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FilledButton.tonal(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text("Cancel"),
                ),
                const SizedBox(width: 10),
                FilledButton(
                    onPressed:
                        !RegExp("^\\d+.+\$").hasMatch(key) || name.isEmpty
                            ? null
                            : () {
                                widget.onSubmit(Tournament(key, name));
                                Navigator.of(context).pop();
                              },
                    child: const Text("Save"))
              ],
            )
          ],
        ),
      ),
    );
  }
}
