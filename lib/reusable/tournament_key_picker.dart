import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:scouting_dashboard_app/datatypes.dart';

import 'package:scouting_dashboard_app/reusable/lovat_api.dart';
import 'package:skeletons/skeletons.dart';

class TournamentKeyPicker extends StatefulWidget {
  const TournamentKeyPicker({
    super.key,
    this.decoration,
  });

  final InputDecoration? decoration;

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
    late final List<Tournament> tournaments;

    try {
      tournaments = (await lovatAPI.getTournaments()).tournaments;

      setState(() {
        this.tournaments = tournaments;
      });
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
  }

  Future<void> setInitialTournament() async {
    try {
      final current = await Tournament.getCurrent();

      if (current != null) {
        setState(() {
          selectedItem = current;
        });
      }

      setState(() {
        initialized = true;
      });
    } catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          "Error getting current tournament: $error",
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
    }
  }

  @override
  void initState() {
    super.initState();

    setInitialTournament();
    getTournaments();
  }

  Future<void> handleChange(Tournament? tournament) async {
    if (tournament == null) {
      return;
    }

    await tournament.storeAsCurrent();

    setState(() {
      selectedItem = tournament;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ((tournaments.isEmpty || !initialized) && !hasError)
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
                onChanged: handleChange,
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
                          onSubmit: handleChange,
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
