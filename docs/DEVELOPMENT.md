# AutoReady – UT99 mutator: backlog, guide and development log

Rules, constraints and conventions for working on the project are in `CLAUDE.md`.

Last updated: 2026-10-16 · Giulio Celidoni

## Current status (restart point)

The latest build is **AutoReady v1.2, `AutoReady.u` 21,593 bytes (md5 `68c7c4800c8f15763ae6a8d9ce86dbd0`)**, installed on the server and tested with a single player.

| Item | Location |
|---|---|
| Source | `AutoReady/Classes/AutoReady.uc` in this repository |
| Compiled package | `/opt/ut99-server/System/AutoReady.u` (server) |
| Configuration | `/opt/ut99-server/System/AutoReady.ini` (template: `AutoReady.ini.example`) |
| Older sources (pre-git) | `AutoReady.uc.v1.bak`, `AutoReady.uc.v11-it.bak`, `AutoReady.uc.v11.bak` in `~/Scrivania/backup/AutoReady/Classes/` |

> Since the upgrade to OldUnreal 469f, binaries and ini files on Linux live in `System/` instead of `System64/`.

**Tested and working (28/09, single player with `MinReadyPlayers=1`):** start on Fire, countdown with players back in the waiting state, `MaxPlayers` restored once the match starts, `mutate ar hold` / `mutate ar start`, logging and debug.

## Backlog

Open items, newest first. Tick them off (or remove them) when done and record the outcome in "Development log".

**Testing v1.2**

- [ ] Two clients, `MinReadyPlayers=2`: no timeout in a duel, status message in chat, disconnect during the countdown (start cancelled), `mutate ar status`.
- [ ] Three or more clients: majority timeout, on-screen countdown, player forced ready by the timeout.
- [ ] Teams (TDM) with `bRequireBalancedTeams=True`.
- [ ] After testing: `AutoReady.ini` with `MinReadyPlayers=2` and `bDebug=False`, edited with the server stopped.

**Build and release**

- [ ] Publish the first release (`v1.2`) from CI and install it on the server; the CI build is compiled against 469f-rc5, so its size and md5 differ from the 469e-era build above.
- [ ] Update "Current status" with the size and md5 of the released `AutoReady.u`.

## What AutoReady is and why it exists

AutoReady lets you use **tournament mode** (everyone presses Fire to say "I'm ready") without having to fill the server.

In UT99, tournament mode only starts the match when the number of connected players is **equal** to `MaxPlayers`. With `MaxPlayers=10` and 6 friends at a LAN party, the match never starts: everyone keeps waiting, even after pressing Fire.

AutoReady solves this: when all present players are ready, it temporarily lowers `MaxPlayers` to the number of players present. The game sees a "full" server, runs the 10…1 countdown and starts the match. As soon as the match has started, AutoReady restores the original `MaxPlayers`, so late joiners can still enter.

It also handles latecomers: if a majority is ready and someone does not press Fire, after a set time that player is marked ready automatically.

It runs server-side only: clients download nothing.

## How it works, step by step

Every second AutoReady checks the situation and does exactly one of the following.

1. **Tournament mode off** (`bTournament=False`): logs that there is nothing to do and disables itself for the rest of the map.
2. **Match already started**: restores the original `MaxPlayers`, logs a summary and disables itself.
3. **Counts players.** Anyone who is not a real spectator (class `Spectator`) counts as a player. Players waiting for the match count, even if UT temporarily flags them as spectators. Bots do not count.
4. **Too few players** (fewer than `MinReadyPlayers`): waits, no timeout.
5. **Admin hold active** (`mutate ar hold`): starts nothing and repeats "Start on hold by admin" at screen centre.
6. **More than half ready, but not everyone**: starts the `ReadyTimeout` timer. In the last 10 seconds it shows "Forced start in N s - press Fire!" at screen centre. When it expires, latecomers are marked ready.
7. **Everyone ready** (and teams balanced, if required): saves the current `MaxPlayers`, lowers it to the player count and the game starts the 10…1 countdown.
8. **During the countdown**: if someone joins or leaves, `MaxPlayers` is realigned with the player count. If players drop below `MinReadyPlayers`, the start is cancelled and the original `MaxPlayers` is restored.
9. **Status messages**: every `MessageInterval` seconds, the number of ready players is posted in chat.

## Installation and upgrade

Installation only requires copying `AutoReady.u` to the server and enabling it in game configurations with `bTournament=True`.

**First install or upgrade**

1. Stop the server: `sudo systemctl stop ut99-server`.
2. Copy `AutoReady.u` to `/opt/ut99-server/System/` and check its size with `ls -la AutoReady.u` (21,593 bytes for the current v1.2).
3. Do **not** add it to `ServerPackages`: it runs server-side only.
4. Create or update `System/AutoReady.ini` (see "Configuration" in `README.md`). Lines must not have leading spaces.
5. Start the server: `sudo systemctl start ut99-server`.
6. Check the startup line in the journal: `journalctl -u ut99-server.service --since "5 min ago" | grep "v1.2 active"`.

**Enabling it**

Add `AutoReady.AutoReady` to the mutators of every game configuration that uses tournament mode (`bTournament=True`), for example on the server command line (`?Mutator=AutoReady.AutoReady`) or in the mutator list of the game configuration. Combine it with other mutators as a comma-separated list. Keep `MinPlayers=0` and `InitialBots=0`: bots are not counted. In configurations with `bTournament=False` AutoReady is not needed; if present, it disables itself.

## Admin commands

Commands are typed in the game console. Admin commands require `adminlogin <password>` first.

| Command | Who | Effect |
|---|---|---|
| `mutate ar status` | Anyone | Shows the requester how many players are ready and the full list of who is missing. Also reports an admin hold or a match already started. |
| `mutate ar start` | Admin | Marks all present players ready and clears any hold: the countdown starts on the next second. Centre: "Admin forced start". |
| `mutate ar hold` | Admin | Blocks the automatic start until `mutate ar start`. Stops the timeout and, if the countdown had started, restores the original `MaxPlayers`. Centre, every 3 s: "Start on hold by admin". |

Once the match has started, admin commands reply "match already started". An unknown command replies with the list of valid commands.

## Logging, debug and troubleshooting

Read the log from the **systemd journal**, not `ucc.log`. `ucc.log` is written in 32 KB blocks, so recent lines stay in memory.

The journal strips the `AutoReady:` prefix, so search for the message text:

```bash
journalctl -u ut99-server.service --since "10 min ago" | grep -E "v1\.2 active|\[debug\]|ready|MaxPlayers|countdown|timeout|match started|nothing to do"
```

**Normal lines (always logged)**

| Line | Meaning |
|---|---|
| `v1.2 active - MinReady=2 Timeout=30s Balanced=False Debug=False` | Mutator loaded, with the values read from the `.ini`. |
| `majority ready (4/6), 30s timeout started` | Latecomer timeout started. |
| `timeout expired with 5/6 ready, marked ready: Mario` | Timeout expired, list of players forced ready. |
| `all players ready, MaxPlayers 10 -> 6, countdown started` | Start: `MaxPlayers` lowered. |
| `player count changed during countdown, MaxPlayers 6 -> 5` | Realignment during the countdown. |
| `player count dropped to 1, start cancelled, MaxPlayers restored to 10` | Start cancelled. |
| `match started: 6 players, waited 42s, 1 forced ready (Mario), MaxPlayers restored to 10` | Summary once the match starts. |
| `admin Giulio forced start` / `put start on hold` | Admin commands. |

**`[debug]` lines (with `bDebug=True`)**: one line per state change, with present, ready, `NumPlayers`, `MaxPlayers`, `CountDown`, timeout, admin hold and, for each player, name, class, `ready`, `spec`, `waiting` and state name (e.g. `PlayerWaiting`). During the countdown one line per second is logged because `CountDown` changes.

**Known issues already encountered**

| Symptom | Cause | Fix |
|---|---|---|
| Startup line shows `MinReady=2` although the `.ini` says 1 | `.ini` edited while the server was running, or lines with leading spaces | Edit with the server stopped, no leading spaces (`sed -i 's/^[[:space:]]*//' AutoReady.ini`) |
| The match never starts with everyone ready | Below `MinReadyPlayers`, or an old build (see log, spectator bug) | Check the startup line and the size of `AutoReady.u` |
| `grep AutoReady` on the journal finds nothing | The journal strips the tag | Search the message text (command above) |
| `Unknown Mutator in use: AutoReady.AutoReady` | Message from another component that does not recognise the name | Harmless |

## Known limitations

- **Joining during the countdown:** for the 10 seconds of the countdown `MaxPlayers` equals the player count, so anyone connecting is rejected or joins as a spectator. Unavoidable: the game checks `NumPlayers == MaxPlayers` every second.
- **Waiting players look like spectators:** in stock UT a player waiting for the match (`PlayerPawn` state `PlayerWaiting`) has `bIsSpectator=True`. AutoReady therefore identifies spectators only by the `Spectator` class.
- **Stock match start:** AutoReady does not start the match itself; it only makes the stock condition (`NumPlayers == MaxPlayers` and everyone `bReadyToPlay`) true, so the match starts through the normal `DeathMatchPlus` code path (countdown, `StartMatch`).
- **`MaxPlayers` changed after initialization:** other actors may set `MaxPlayers` after `InitGame`. AutoReady reads it only when lowering it, so it restores the value actually in use.
- **Bots:** not counted and never press Fire.
- **Centre-screen messages:** use the standard `CriticalEvent` type (light blue, a few seconds). To keep them on screen longer they are re-sent every second (countdown) or every 3 s (admin hold). A custom message class would require `ServerPackages` and a client download: rejected.
- **Gametypes:** DeathMatchPlus and subclasses only (DM, TDM, CTF, Domination, Assault).

## Build

**CI (GitHub Actions).** `.github/workflows/build.yml` runs on every push and pull request:

- installs UT99 GOTY + the OldUnreal patch selected in `ut-patch.conf` with the official OldUnreal installer (`scripts/setup-ut.sh`, accepting the Epic Games Terms of Service);
- caches that installation per patch tag, so the game is downloaded again only when the patch changes (`UT_PATCH=newest` also follows release candidates);
- compiles `AutoReady.u` with `scripts/compile.sh` and uploads it with its md5 and the `ucc make` log.

Pushing a tag `vX.Y` also publishes a GitHub Release with `AutoReady.u` and its md5.

**Local.** Against any complete UT99 Linux installation:

```bash
scripts/compile.sh <ut99-dir>      # output in build/
```

**Manual procedure** (what `compile.sh` does).

On Linux, `ucc-bin-amd64` (469e and 469f) needs a small helper library, otherwise `ucc make` hangs on "Analyzing..." and runs out of memory.

**The bug.** When scanning sources in `Classes/`, `ucc make` does not skip the `.` entry (the directory itself) and recurses endlessly into `Classes/./././…`. It happens with any package, even a 3-line mutator. The `nodots.so` library, loaded with `LD_PRELOAD`, hides `.` and `..` from directory listings.

**Requirements:** a complete UT99 Linux installation (`System`, `SystemLocalized`, `Textures`, `Sounds`). Without `Sounds`, Botpack fails to load and `ucc` tries to recompile it. A copy is in `~/Scrivania/backup/ut99/`.

**Procedure**

1. Build the library (once), from `tools/nodots.c` in this repository:

   ```bash
   gcc -shared -fPIC -o nodots.so tools/nodots.c -ldl
   ```

2. Put the source in `<ut99>/AutoReady/Classes/AutoReady.uc`. The `Classes` folder must contain **only `.uc` files**.
3. Create `System/Build.ini` by copying `Default.ini` and keeping only these `EditPackages`, in this order: `Core`, `Engine`, `Editor`, `UWindow`, `Fire`, `IpDrv`, `UWeb`, `UBrowser`, `UnrealShare`, `UnrealI`, `UMenu`, `Botpack`, `AutoReady`. Later packages (UTMenu etc.) are not needed and, without their sources, break the build.
4. Delete the old `System/AutoReady.u`: if it exists, `ucc` does not recompile.
5. Compile:

   ```bash
   cd <ut99>/System
   LD_PRELOAD=/path/to/nodots.so ./ucc-bin-amd64 make ini=Build.ini -nohomedir
   ```

It must end with `Success - 0 error(s), 0 warnings`. `Failed to load AutoReady` warnings before compilation are normal.

## Development log

AutoReady was created because stock UT99 offers no way to start a tournament-mode match without a full server. Builds are listed newest first. From now on, changes are tracked in git history; add a row here for each new build.

| Date | Build | What changed | Why |
|---|---|---|---|
| 16/10 | – | Project moved to git; documentation translated to English. | Version control and consistency with the English standard. |
| 28/09 | v1.2 · 21,593 bytes · md5 `68c7c480…` | Timeout only if someone is still missing. Centre countdown in the last 10 s. "On hold" repeated every 3 s. | Testing showed a useless "timeout started" with everyone ready. Centre messages disappeared too soon. |
| 28/09 | v1.2 · 21,157 bytes | Spectators identified only by the `Spectator` class. | **Bug:** a player in `PlayerWaiting` has `bIsSpectator=True`, was discarded and the start cancelled after 2 s (endless wait). Tested: match started. |
| 28/09 | v1.2 · 21,218 bytes | First fix attempt using `bWaitingPlayer`. | Superseded by the next, more robust build. |
| 28/09 | v1.2 · 20,836 bytes | `bDebug` flag with `[debug]` lines on each state change. | Needed to find where the start got stuck. |
| 28/09 | v1.2 | Configuration moved to `AutoReady.ini` (`config(AutoReady)`). | Giulio's choice: separate file. |
| 28/09 | v1.2 | Removed `MajorityPercent` and the "timeout only with 3+ players" rule: fixed "more than half" threshold. | One parameter fewer. With 51% rounded up a duel already required both players. |
| 28/09 | v1.2 | Same status message for everyone. | Giulio's choice: details via `mutate ar status`. |
| 28/09 | v1.2 | `mutate ar status/start/hold` commands. Log summary once the match starts. Removed `bCenterMessages`. | Handling real LAN situations (absentees, waiting). |
| 28/09 | v1.1 | `SaveConfig()` at startup. | The config section was never written. |
| 27/09 | v1.1 | Messages and log in English. | Standard for all mutators. |
| 27/09 | v1.1 | `LogAR`/`Announce` helpers, startup banner, messages for every event, `bCenterMessages`. | Visibility for players and admins. |
| 27/09 | v1 | First version: lowers `MaxPlayers` to the player count when everyone is ready, majority timeout, realignment during the countdown, restore on start. | Start tournament mode without a full server. |

**Findings that shaped the project**

- In `DeathMatchPlus.Timer` the tournament countdown only decreases if `NumPlayers == MaxPlayers` and everyone has `bReadyToPlay`.
- In stock UT, `DeathMatchPlus` puts new players in `PlayerPawn` state `PlayerWaiting` when ready-up is required, and that state sets `PlayerReplicationInfo.bIsSpectator=True` (and `bWaitingPlayer=True`); `EndState` clears them.
- The systemd journal strips the log tag; `ucc.log` is written in 32 KB blocks.
- Copies to the `backup` folder sometimes wrote the old file: always verify size and md5 after each delivery.
