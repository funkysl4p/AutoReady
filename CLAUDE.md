# AutoReady – rules for working on the project

All rules, constraints and conventions live here. Overview, installation and
configuration for users live in `README.md`; descriptions, build, procedures,
backlog and history in `docs/DEVELOPMENT.md`.

## Repository layout

```
AutoReady/Classes/        UnrealScript sources (*.uc)
AutoReady.ini.example     default configuration
README.md                 user documentation: overview, installation, configuration
docs/DEVELOPMENT.md       backlog, behaviour, build, development log
scripts/compile.sh        compile AutoReady.u against a UT99 installation
scripts/setup-ut.sh       install UT99 + a given OldUnreal patch (used by CI)
scripts/resolve-patch.sh  resolve the patch tag from ut-patch.conf
tools/nodots.c            LD_PRELOAD shim for the ucc make loop on Linux
ut-patch.conf             OldUnreal patch used by CI
.github/workflows/        CI build
```

Keep this layout up to date when files are added, moved or removed.

## Design constraints (do not regress)
- Identify spectators only by class (`IsA('Spectator')`), never by
  `PlayerReplicationInfo.bIsSpectator`: in stock UT the `PlayerPawn` state
  `PlayerWaiting` (players waiting for the match) sets `bIsSpectator=True`.
- Read the original `MaxPlayers` when lowering it, not in `PostBeginPlay`:
  other actors may change it after `InitGame`.
- Start the match only through the stock condition in `DeathMatchPlus.Timer`
  (`NumPlayers == MaxPlayers` and every player `bReadyToPlay`): never call
  `StartMatch` or touch `CountDown` directly.
- During the countdown `MaxPlayers` follows the player count; restore the
  original value once the match starts.
- The timeout starts when more than half is ready (`Present/2 + 1`); keep it
  fixed, not configurable.
- Server-side only: never require `ServerPackages` or client downloads (no
  custom LocalMessage classes; centre messages use `CriticalEvent`).
- Configuration stays in `AutoReady.ini` (`config(AutoReady)`), written with
  `SaveConfig()` at startup.
- Supported gametypes: `DeathMatchPlus` and subclasses; disable otherwise.
- If a change requires breaking one of these, say so explicitly and update
  this list in the same commit.

## UnrealScript 469
- No `Eval()`: use the `IfStr` helper in `AutoReady.uc`.
- A string literal cannot span lines.
- `Classes/` contains only `.uc` files.
- `ucc make` skips packages that already exist: delete the old `AutoReady.u`
  before compiling (`scripts/compile.sh` does it).
- On Linux `ucc make` needs the `tools/nodots.c` preload shim (469e and 469f).

## Conventions
- Code comments, on-screen messages, log lines and documentation in English.
- Describe and justify behaviour only in terms of stock UT99 (Engine,
  Botpack). Never mention third-party mods or mutators in code or
  documentation.
- Commit messages in English, imperative mood.
- Never commit passwords, real server `.ini` files or UT99 game files.

## Workflow
- `README.md` "Configuration" is the reference for users: every
  `AutoReady.ini` parameter is documented there and only there. When a config
  variable is added, removed or changes default, update in the same commit
  the README table, `AutoReady.ini.example` and `defaultproperties` in
  `AutoReady.uc`.
- `README.md` "Behaviour for each use case" describes the functional
  behaviour for users: when a change alters what players or admins see
  (start conditions, messages, timings), update that table in the same commit.
- A change is verified by the CI build: it must end with
  `Success - 0 error(s)`. Locally: `scripts/compile.sh <ut99-dir>`.
- Do not report a change as working until the CI build has passed; even then
  state that it is untested in game.
- For every new build: bump `VERSION` in `AutoReady.uc`, update
  "Current status", "Backlog" and "Development log" in `docs/DEVELOPMENT.md`.
- Releases: tag `vX.Y` on `main`; CI publishes `AutoReady.u` and its md5.
  Do not create tags or releases unless asked.
- Deployment is manual: do not add deploy automation and do not act on the
  server.
- Keep `ut-patch.conf` in line with the OldUnreal patch installed on the
  server.
- The CI accepts the Epic Games Terms of Service through
  `UT_ACCEPT_EPIC_TOS=1`; do not remove the opt-in check in
  `scripts/setup-ut.sh`.
