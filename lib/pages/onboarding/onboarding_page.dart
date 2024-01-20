import 'dart:convert';

import 'package:auth0_flutter/auth0_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:scouting_dashboard_app/constants.dart';
import 'package:scouting_dashboard_app/datatypes.dart';
import 'package:scouting_dashboard_app/reusable/friendly_error_view.dart';
import 'package:scouting_dashboard_app/reusable/lovat_api.dart';
import 'package:scouting_dashboard_app/reusable/models/team.dart';
import 'package:scouting_dashboard_app/reusable/page_body.dart';
import 'package:scouting_dashboard_app/reusable/push_widget_extension.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skeletons/skeletons.dart';
import 'package:url_launcher/url_launcher.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  var phase = OnboardingPagePhase.loading;
  Team? team;
  String? teamEmail;

  Future<void> init() async {
    try {
      final credentials = await auth0.credentialsManager.credentials();

      final profile = await lovatAPI.getUserProfile();

      if (profile.team != null) {
        toRegistrationStatusView(profile.team!);
      } else {
        setState(() {
          phase = OnboardingPagePhase.teamSelection;
        });
      }
    } on CredentialsManagerException catch (e) {
      if (e.code == "NO_CREDENTIALS") {
        setState(() {
          phase = OnboardingPagePhase.welcome;
        });
      } else if (e.code == "NO_REFRESH_TOKEN") {
        debugPrint("No refresh token");
        setState(() {
          phase = OnboardingPagePhase.welcome;
        });
      } else {
        debugPrint(e.toString());
      }
    }
  }

  @override
  void initState() {
    super.initState();

    init();

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }

  @override
  void dispose() {
    super.dispose();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return {
          OnboardingPagePhase.welcome: welcomePage(context),
          OnboardingPagePhase.loading: const LoadingPage(),
          OnboardingPagePhase.username: UsernamePage(
            onSubmit: () => setState(() {
              phase = OnboardingPagePhase.teamSelection;
            }),
          ),
          OnboardingPagePhase.teamSelection: TeamNumberPage(
            onSubmit: (t) async {
              if (t == null) {
                setState(() {
                  team = null;
                });

                toSettingsOnboarding();
                return;
              }

              await toRegistrationStatusView(t);
            },
          ),
          OnboardingPagePhase.registerTeamChoice: registerTeamChoicePage(),
          OnboardingPagePhase.teamEmail: TeamEmailPage(
            team: team ?? const Team(number: 0, name: ''),
            onSubmit: (email) {
              setState(() {
                teamEmail = email;
                phase = OnboardingPagePhase.emailVerification;
              });
            },
            onBack: () => setState(() {
              phase = OnboardingPagePhase.registerTeamChoice;
            }),
          ),
          OnboardingPagePhase.emailVerification: EmailVerificationPage(
            onBack: () => setState(() {
              phase = OnboardingPagePhase.teamSelection;
            }),
            onSubmit: () => toRegistrationStatusView(team!),
            team: team ?? const Team(number: 0, name: ''),
          ),
          OnboardingPagePhase.error: const FriendlyErrorView(),
          OnboardingPagePhase.teamCode: TeamCodePage(
            team: team ?? const Team(number: 0, name: ''),
            onBack: () => setState(() {
              phase = OnboardingPagePhase.teamSelection;
            }),
            onSubmit: () => toRegistrationStatusView(team!),
          ),
          OnboardingPagePhase.teamDataSettings: SourceTeamSettingsPage(
            team: team,
            onSubmit: () {
              setState(() {
                phase = OnboardingPagePhase.tournamentSettings;
              });
            },
          ),
        }[phase] ??
        Center(child: Text("Error: Unknown phase $phase"));
  }

  Future<void> toRegistrationStatusView(Team? t) async {
    setState(() {
      team = t;
      phase = OnboardingPagePhase.loading;
    });

    try {
      final profile = await lovatAPI.getUserProfile();
      final teamNumber = t?.number ?? profile.team?.number;
      final status = teamNumber == null
          ? null
          : await lovatAPI.getRegistrationStatus(
              teamNumber); // The status of the team, not the user

      final isUsernameSet = profile.username != null;

      if (!isUsernameSet) {
        setState(() {
          phase = OnboardingPagePhase.username;
        });
      } else if (status == null) {
        setState(() {
          phase = OnboardingPagePhase.teamSelection;
        });
      } else if (status == RegistrationStatus.notStarted) {
        setState(() {
          phase = OnboardingPagePhase.registerTeamChoice;
        });
      } else if (status == RegistrationStatus.registeredNotOnTeam) {
        setState(() {
          phase = OnboardingPagePhase.teamCode;
        });
      } else if (status == RegistrationStatus.pendingEmailVerification) {
        setState(() {
          phase = OnboardingPagePhase.emailVerification;
        });
      } else if (status == RegistrationStatus.pendingTeamWebsite) {
        setState(() {
          phase = OnboardingPagePhase.teamWebsite;
        });
      } else if (status == RegistrationStatus.pendingTeamVerification) {
        setState(() {
          phase = OnboardingPagePhase.teamVerification;
        });
      } else if (status == RegistrationStatus.registeredOnTeam) {
        toSettingsOnboarding();
      } else {
        debugPrint("Unknown registration status: $status");
        setState(() {
          phase = OnboardingPagePhase.error;
        });
      }
    } catch (e) {
      debugPrint(e.toString());
      setState(() {
        phase = OnboardingPagePhase.error;
      });
    }
  }

  Widget welcomePage(BuildContext context) {
    return Scaffold(
      body: PageBody(
        child: Stack(children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("Welcome to",
                  style: TextStyle(
                    fontSize: 20,
                    height: 1,
                  )),
              Text(
                "Lovat",
                style: TextStyle(
                  fontSize: 100,
                  color: Theme.of(context).colorScheme.primary,
                  height: 1,
                ),
              ),
            ],
          ),
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Column(
              children: [
                FilledButton(
                  onPressed: login,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 30),
                    child: Text("Get started"),
                  ),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Future<void> login() async {
    try {
      setState(() {
        phase = OnboardingPagePhase.loading;
      });

      final credentials = await auth0.webAuthentication().login(
            audience: "https://api.lovat.app",
          );

      debugPrint((await auth0.credentialsManager.credentials()).accessToken);

      toRegistrationStatusView(null);
    } catch (e) {
      debugPrint(e.toString());

      setState(() {
        phase = OnboardingPagePhase.welcome;
      });
    }
  }

  void onBoardingCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setInt("onboardingVersion", 1);

    Navigator.of(context).pushNamedAndRemoveUntil(
      '/match_schedule',
      (route) => false,
    );
  }

  void toSettingsOnboarding() {
    setState(() {
      phase = OnboardingPagePhase.teamDataSettings;
    });
  }

  Widget registerTeamChoicePage() {
    return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              setState(() {
                phase = OnboardingPagePhase.teamSelection;
              });
            },
          ),
        ),
        body: PageBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Text(
                "Register",
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              Text(
                "${team?.name}?",
                style: Theme.of(context).textTheme.headlineMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              Text(
                "You are the first person on ${team?.number} to sign up for Lovat. Would you like to register on behalf of your team? You should only do this if you're in charge of your team's scouting.",
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const Spacer(),
              FilledButton(
                onPressed: () async {
                  setState(() {
                    phase = OnboardingPagePhase.teamEmail;
                  });
                },
                child: const Text("Register team"),
              ),
              TextButton(
                onPressed: () {
                  toSettingsOnboarding();
                },
                child: const Text("Just looking around"),
              ),
            ],
          ),
        ));
  }
}

class LoadingPage extends StatelessWidget {
  const LoadingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: PageBody(
        child: Center(
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }
}

class SourceTeamSettingsPage extends StatefulWidget {
  const SourceTeamSettingsPage({
    super.key,
    this.team,
    this.onSubmit,
  });

  final Team? team;
  final dynamic Function()? onSubmit;

  @override
  State<SourceTeamSettingsPage> createState() => _SourceTeamSettingsPageState();
}

class _SourceTeamSettingsPageState extends State<SourceTeamSettingsPage> {
  SourceTeamSettingsMode? mode;
  List<Team>? teams;

  bool loading = false;
  String? error;

  bool get isValid => mode != null;

  Future<void> submit() async {
    setState(() {
      error = null;
    });

    if (mode == SourceTeamSettingsMode.specificTeams) {
      Navigator.of(context).pushNamed(
        '/specific_source_teams',
        arguments: SpecificSourceTeamsArguments(
          onSubmit: (teams) async {
            setState(() {
              this.teams = teams;
            });

            try {
              setState(() {
                loading = true;
              });

              await lovatAPI.setSourceTeams(
                SourceTeamSettingsMode.specificTeams,
                teams: teams.map((e) => e.number).toList(),
              );

              widget.onSubmit?.call();
              Navigator.of(context).popUntil((a) => a.isFirst);
            } catch (e) {
              debugPrint(e.toString());
              setState(() {
                error = "Error setting source teams";
              });
            } finally {
              setState(() {
                loading = false;
              });
            }
          },
        ),
      );
    } else {
      try {
        setState(() {
          loading = true;
        });

        await lovatAPI.setSourceTeams(mode!);

        widget.onSubmit?.call();
      } catch (e) {
        debugPrint(e.toString());
        setState(() {
          error = "Error setting source teams";
        });
      } finally {
        setState(() {
          loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "Where should we source your data?",
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: SourceTeamSettingsMode.values
                  .where((element) =>
                      widget.team != null ||
                      element != SourceTeamSettingsMode.thisTeam)
                  .map(
                    (option) =>
                        option.widget(context, widget.team, mode == option, () {
                      setState(() {
                        mode = option;
                      });
                    }),
                  )
                  .toList()
                  .withSpaceBetween(height: 20),
            ),
            const Spacer(),
            if (error != null) ...[
              Text(
                error!,
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
            ],
            FilledButton(
              onPressed: isValid && !loading ? submit : null,
              child: loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    )
                  : const Text("Next"),
            ),
          ].withSpaceBetween(height: 14),
        ),
      ),
    );
  }
}

class SpecificSourceTeamsArguments {
  const SpecificSourceTeamsArguments({
    required this.onSubmit,
  });

  final dynamic Function(List<Team> teams) onSubmit;
}

class SpecificSourceTeamPage extends StatefulWidget {
  const SpecificSourceTeamPage({
    super.key,
    this.onSubmit,
  });

  final dynamic Function(List<Team> teams)? onSubmit;

  @override
  State<SpecificSourceTeamPage> createState() => _SpecificSourceTeamPageState();
}

class _SpecificSourceTeamPageState extends State<SpecificSourceTeamPage> {
  List<Team>? teams;
  List<Team>? filteredTeams;
  List<Team> selectedTeams = [];
  String? error;
  bool submitLoading = false;
  String filterText = '';

  void fetchTeams() async {
    try {
      final teamList = await lovatAPI.getTeams();

      setState(() {
        teams = teamList.teams;
        filterTeams(filterText);
      });
    } catch (e) {
      debugPrint(e.toString());
      setState(() {
        error = "Error fetching teams";
      });
    }
  }

  @override
  void initState() {
    super.initState();
    fetchTeams();
  }

  void filterTeams(String value) async {
    final newFilteredTeams = teams?.where((element) {
      return element.name.toLowerCase().contains(value.toLowerCase()) ||
          element.number.toString().contains(value);
    }).toList();

    setState(() {
      filteredTeams = newFilteredTeams;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageBody(
        padding: EdgeInsets.zero,
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16).copyWith(bottom: 0),
                  child: Column(
                    children: [
                      Text(
                        "Choose teams",
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      TextField(
                        onChanged: (text) {
                          filterTeams(text);
                          setState(() {
                            filterText = text;
                          });
                        },
                        decoration: const InputDecoration(
                          filled: true,
                          labelText: "Search",
                        ),
                        autofocus: true,
                      )
                    ].withSpaceBetween(height: 14),
                  ),
                ),
                if (filteredTeams == null) ...[
                  Expanded(child: SkeletonListView()),
                ] else ...[
                  Expanded(
                    child: ListView.builder(
                      itemCount: filteredTeams!.length,
                      itemBuilder: (context, index) {
                        final team = filteredTeams![index];

                        return ListTile(
                            title: Text(team.name),
                            subtitle: Text(team.number.toString()),
                            trailing: Checkbox(
                              value: selectedTeams.contains(team),
                              onChanged: (value) {
                                setState(() {
                                  if (value == true) {
                                    selectedTeams.add(team);
                                  } else {
                                    selectedTeams.remove(team);
                                  }
                                });
                              },
                            ),
                            onTap: () => {
                                  setState(() {
                                    if (selectedTeams.contains(team)) {
                                      selectedTeams.remove(team);
                                    } else {
                                      selectedTeams.add(team);
                                    }
                                  })
                                });
                      },
                    ),
                  ),
                ],
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (error != null) ...[
                    Text(
                      error!,
                      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                            color: Theme.of(context).colorScheme.error,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                  ],
                  FilledButton(
                    onPressed: selectedTeams.isEmpty || submitLoading
                        ? null
                        : () async {
                            try {
                              setState(() {
                                submitLoading = true;
                                error = null;
                              });
                              await widget.onSubmit?.call(selectedTeams);
                            } catch (e) {
                              setState(() {
                                error = "Error setting source teams";
                              });
                            } finally {
                              setState(() {
                                submitLoading = false;
                              });
                            }
                          },
                    child: submitLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 3),
                          )
                        : const Text("Next"),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum SourceTeamSettingsMode {
  thisTeam,
  allTeams,
  specificTeams,
}

extension SourceTeamSettingsModeExtension on SourceTeamSettingsMode {
  String get identifier {
    switch (this) {
      case SourceTeamSettingsMode.thisTeam:
        return "THIS_TEAM";
      case SourceTeamSettingsMode.allTeams:
        return "ALL_TEAMS";
      case SourceTeamSettingsMode.specificTeams:
        return "SPECIFIC_TEAMS";
    }
  }

  String description(Team? team) {
    switch (this) {
      case SourceTeamSettingsMode.thisTeam:
        return "Collected only by ${team?.number ?? 'your team'}";
      case SourceTeamSettingsMode.allTeams:
        return "Collected by any team";
      case SourceTeamSettingsMode.specificTeams:
        return "Choose specific teams";
    }
  }

  String get imagePrefix {
    switch (this) {
      case SourceTeamSettingsMode.thisTeam:
        return "only_team_";
      case SourceTeamSettingsMode.allTeams:
        return "any_team_";
      case SourceTeamSettingsMode.specificTeams:
        return "specific_teams_";
    }
  }

  String imagePath(bool selected) {
    return "assets/images/$imagePrefix${selected ? 'selected' : 'default'}.png";
  }

  Widget widget(
    BuildContext context,
    Team? team,
    bool selected,
    dynamic Function() onPressed,
  ) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: selected
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary,
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: AnimatedCrossFade(
              firstChild: Image.asset(imagePath(true)),
              secondChild: Image.asset(imagePath(false)),
              crossFadeState: selected
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              duration: const Duration(
                milliseconds: 250,
              ), // TODO: Check if this looks good in release mode
            ),
          ),
          Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onPressed,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Opacity(
                      opacity: 0,
                      child: Image.asset(
                        imagePath(selected),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    child: Text(
                      description(team),
                      style: Theme.of(context).textTheme.titleMedium!.copyWith(
                            color: selected
                                ? Theme.of(context).colorScheme.onPrimary
                                : Theme.of(context)
                                    .colorScheme
                                    .onPrimaryContainer,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class UsernamePage extends StatefulWidget {
  const UsernamePage({
    super.key,
    this.onSubmit,
  });

  final dynamic Function()? onSubmit;

  @override
  State<UsernamePage> createState() => _UsernamePageState();
}

class _UsernamePageState extends State<UsernamePage> {
  String username = '';
  String? error;
  bool loading = false;

  Future<void> submit() async {
    setState(() {
      error = null;
    });

    try {
      setState(() {
        loading = true;
      });

      await lovatAPI.setUsername(username);

      widget.onSubmit?.call();
    } catch (e) {
      debugPrint(e.toString());
      setState(() {
        error = "Error setting username";
      });
    } finally {
      setState(() {
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "Choose a name",
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            TextField(
              onChanged: (value) {
                setState(() {
                  username = value;
                  error = null;
                });
              },
              decoration: InputDecoration(
                filled: true,
                label: const Text("Username"),
                errorText: error,
              ),
              autofocus: true,
              keyboardType: TextInputType.name,
              textInputAction: TextInputAction.next,
              onSubmitted: (value) {
                if (username.isNotEmpty) {
                  submit();
                } else {
                  setState(() {
                    error = "Please enter a username";
                  });
                }
              },
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: username.isEmpty || loading ? null : submit,
              child: loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    )
                  : const Text("Next"),
            ),
          ].withSpaceBetween(height: 14),
        ),
      ),
    );
  }
}

class TeamEmailPage extends StatefulWidget {
  const TeamEmailPage({
    super.key,
    required this.team,
    this.onSubmit,
    this.onBack,
  });

  final dynamic Function(String email)? onSubmit;
  final dynamic Function()? onBack;
  final Team team;

  @override
  State<TeamEmailPage> createState() => _TeamEmailPageState();
}

class _TeamEmailPageState extends State<TeamEmailPage> {
  String email = '';
  String? error;
  bool loading = false;

  Future<void> submit() async {
    setState(() {
      error = null;
    });

    try {
      setState(() {
        loading = true;
      });

      final submittedEmail = jsonDecode(jsonEncode(email));

      debugPrint(email);

      await lovatAPI.registerTeam(widget.team.number, submittedEmail);

      widget.onSubmit?.call(submittedEmail);
    } catch (e) {
      debugPrint(e.toString());
      setState(() {
        error = "Error setting email";
      });
    } finally {
      setState(() {
        loading = false;
      });
    }
  }

  bool validateEmail(String value) {
    return RegExp(r"^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+").hasMatch(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            widget.onBack?.call();
          },
        ),
      ),
      body: PageBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "Enter your team's email address",
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            TextField(
              onChanged: (value) {
                setState(() {
                  email = value;
                  error = null;
                });
              },
              decoration: InputDecoration(
                filled: true,
                label: const Text("Email"),
                errorText: error,
              ),
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              onSubmitted: (value) {
                if (validateEmail(email)) {
                  submit();
                } else {
                  setState(() {
                    error = "Please enter a valid email";
                  });
                }
              },
              textCapitalization: TextCapitalization.none,
            ),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: email.isEmpty || loading ? null : submit,
              child: loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    )
                  : const Text("Next"),
            ),
          ].withSpaceBetween(height: 14),
        ),
      ),
    );
  }
}

class EmailVerificationPage extends StatefulWidget {
  const EmailVerificationPage({
    super.key,
    required this.team,
    this.onBack,
    this.onSubmit,
  });

  final dynamic Function()? onBack;
  final dynamic Function()? onSubmit;
  final Team team;

  @override
  State<EmailVerificationPage> createState() => _EmailVerificationPageState();
}

class _EmailVerificationPageState extends State<EmailVerificationPage> {
  bool emailVerifiedLoading = false;
  bool resentEmailLoading = false;

  String? errorText;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              widget.onBack?.call();
            },
          ),
        ),
        body: PageBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Text(
                "Check your email",
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 10),
              Text(
                "We've sent an email to your team with a link to verify that it belongs to you.",
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const Spacer(),
              if (errorText != null) ...[
                Text(
                  errorText!,
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
              ],
              FilledButton(
                onPressed: emailVerifiedLoading
                    ? null
                    : () async {
                        setState(() {
                          emailVerifiedLoading = true;
                          errorText = null;
                        });

                        final status = await lovatAPI
                            .getRegistrationStatus(widget.team.number);

                        if (status ==
                            RegistrationStatus.pendingEmailVerification) {
                          setState(() {
                            errorText = "No, you haven't";
                          });
                        } else {
                          widget.onSubmit?.call();
                        }

                        setState(() {
                          emailVerifiedLoading = false;
                        });
                      },
                child: emailVerifiedLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 3),
                      )
                    : const Text("I've verified the email"),
              ),
              TextButton(
                onPressed: () {},
                child: const Text("Resend email"),
              ),
            ],
          ),
        ));
  }
}

class TeamNumberPage extends StatefulWidget {
  const TeamNumberPage({super.key, this.onSubmit});

  final dynamic Function(Team? team)? onSubmit;

  @override
  State<TeamNumberPage> createState() => _TeamNumberPageState();
}

class _TeamNumberPageState extends State<TeamNumberPage> {
  ScrollController scrollController = ScrollController();

  final Map<int, Team> _teamCache = {};
  int _lastFetchedIndex = 0;
  static const _batchSize = 50;
  int? teamCount;

  String filterText = '';

  Future<Team?> getTeam(int index) async {
    if (_teamCache.containsKey(index)) {
      return _teamCache[index];
    }

    if (index >= _lastFetchedIndex) {
      _lastFetchedIndex = index + _batchSize;
      final partialTeamList = await lovatAPI.getTeams(
        take: _batchSize,
        skip: index,
        filter: filterText,
      );

      final teams = partialTeamList.teams;

      final newTeamCache = Map<int, Team>.from(_teamCache);

      for (int i = 0; i < teams.length; i++) {
        newTeamCache[index + i] = teams[i];
      }

      setState(() {
        _teamCache.clear();
        _teamCache.addAll(newTeamCache);
        teamCount = partialTeamList.total;
      });

      return _teamCache[index];
    } else {
      return null;
    }
  }

  void setFilter(String value) {
    scrollController.animateTo(
      0,
      duration: const Duration(seconds: 0),
      curve: Curves.linear,
    );
    setState(() {
      filterText = value;
      _teamCache.clear();
      _lastFetchedIndex = 0;
      teamCount = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text("Choose your team"),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(80),
            child: Padding(
              padding: const EdgeInsets.all(20).copyWith(top: 10),
              child: TextField(
                onChanged: setFilter,
                decoration: const InputDecoration(
                  filled: true,
                  labelText: "Search",
                ),
                autofocus: true,
              ),
            ),
          ),
        ),
        body: Stack(
          children: [
            teamCount == 0
                ? Center(
                    child: Text(
                    "No teams found",
                    style: Theme.of(context).textTheme.titleLarge,
                  ))
                : ListView.builder(
                    key: Key(filterText),
                    controller: scrollController,
                    prototypeItem: const ListTile(
                      title: Text("Team name"),
                      subtitle: Text("0000"),
                    ),
                    itemCount: teamCount,
                    itemBuilder: teamItemBuilder,
                  ),
            Positioned(
              left: 10,
              right: 10,
              bottom: 10,
              child: SafeArea(
                child: FilledButton.tonal(
                  onPressed: () {
                    widget.onSubmit?.call(null);
                  },
                  child: const Text("I'm not on a team"),
                ),
              ),
            ),
          ],
        ));
  }

  Widget teamItemBuilder(context, index) => FutureBuilder(
      future: getTeam(index),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint(snapshot.error.toString());
        }
        if (snapshot.hasData) {
          final team = snapshot.data;

          if (team == null) {
            return skeletonTeamTile();
          }

          return ListTile(
            title: Text(
              team.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(team.number.toString()),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              widget.onSubmit?.call(team);
            },
          );
        } else {
          return skeletonTeamTile();
        }
      });
}

SkeletonListTile skeletonTeamTile() {
  return SkeletonListTile(
    hasLeading: false,
    hasSubtitle: true,
    padding: const EdgeInsets.symmetric(
      horizontal: 10,
    ),
    titleStyle: const SkeletonLineStyle(
      randomLength: true,
      maxLength: 200,
      minLength: 50,
      height: 22,
    ),
    subtitleStyle: const SkeletonLineStyle(
      width: 50,
      height: 16,
    ),
  );
}

class TeamCodePage extends StatefulWidget {
  const TeamCodePage({
    super.key,
    required this.team,
    this.onSubmit,
    this.onBack,
  });

  final dynamic Function()? onBack;
  final dynamic Function()? onSubmit;
  final Team team;

  @override
  State<TeamCodePage> createState() => _TeamCodePageState();
}

class _TeamCodePageState extends State<TeamCodePage> {
  String code = '';
  String? error;
  bool loading = false;

  Future<void> submit() async {
    setState(() {
      error = null;
    });

    try {
      setState(() {
        loading = true;
      });

      final success = await lovatAPI.joinTeamByCode(widget.team.number, code);

      if (success) {
        widget.onSubmit?.call();
      } else {
        setState(() {
          error = "Invalid code";
        });
      }
    } catch (e) {
      debugPrint(e.toString());
      setState(() {
        error = "Error joining team";
      });
    } finally {
      setState(() {
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            widget.onBack?.call();
          },
        ),
      ),
      body: PageBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "Enter your team's code",
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            TextField(
              onChanged: (value) {
                setState(() {
                  code = value;
                  error = null;
                });
              },
              decoration: InputDecoration(
                filled: true,
                label: const Text("Code"),
                errorText: error,
              ),
              autofocus: true,
              keyboardType: TextInputType.text,
              textInputAction: TextInputAction.next,
              onSubmitted: (value) {
                if (code.isNotEmpty) {
                  submit();
                } else {
                  setState(() {
                    error = "Please enter a code";
                  });
                }
              },
              textCapitalization: TextCapitalization.characters,
              autocorrect: false,
            ),
            const SizedBox(height: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton(
                  onPressed: code.isEmpty || loading ? null : submit,
                  child: loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 3),
                        )
                      : const Text("Next"),
                ),
                Builder(builder: (context) {
                  return TextButton(
                    onPressed: () {
                      FocusManager.instance.primaryFocus?.unfocus();

                      showModalBottomSheet(
                        backgroundColor:
                            Theme.of(context).colorScheme.surfaceVariant,
                        elevation: 0,
                        context: context,
                        builder: (context) => SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  "Where do I find my team's code?",
                                  style:
                                      Theme.of(context).textTheme.headlineSmall,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  "Your team already uses Lovat and has a 6-character code used to invite members. Ask your scouting leadership for it, or reach out to us if you still can't find it.",
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                                const SizedBox(height: 10),
                                FilledButton(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                  },
                                  child: const Text("Close"),
                                ),
                                TextButton(
                                  onPressed: () async {
                                    launchUrl(
                                      Uri.parse("https://lovat.app/support"),
                                      mode: LaunchMode.externalApplication,
                                    );
                                  },
                                  child: const Text("Get help"),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                    child: const Text("I don't have a code"),
                  );
                }),
              ],
            ),
          ].withSpaceBetween(height: 14),
        ),
      ),
    );
  }
}

enum OnboardingPagePhase {
  welcome,
  loading,
  username,
  teamSelection,
  registerTeamChoice,
  teamEmail,
  emailVerification,
  teamWebsite,
  teamVerification,
  teamCode,
  otherUserRegistering,
  teamDataSettings,
  tournamentSettings,
  error,
}
