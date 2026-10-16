# AutoReady – UT99 mutator: guide and development log

Last updated: 2026-10-16 · Giulio Celidoni

## Current status (restart point)

The latest build is **AutoReady v1.2, `AutoReady.u` 21,593 bytes (md5 `68c7c4800c8f15763ae6a8d9ce86dbd0`)**, installed on the server and tested with a single player.

| Item | Location |
|---|---|
| Source | `AutoReady/Classes/AutoReady.uc` in this repository (md5 `c18679e7db738a7836cf9235cc4bb5bd`) |
| Compiled package | `/opt/ut99-server/System/AutoReady.u` (server) |
| Configuration | `/opt/ut99-server/System/AutoReady.ini` (template: `AutoReady.ini.example`) |
| Test preset | `[VS_PresetConfig9]` "TEST - DM AutoReady" in `VoteSysPresets.ini` on the server |
| Older sources (pre-git) | `AutoReady.uc.v1.bak`, `AutoReady.uc.v11-it.bak`, `AutoReady.uc.v11.bak` in `~/Scrivania/backup/AutoReady/Classes/` |

> Since the upgrade to OldUnreal 469f, binaries and ini files on Linux live in `System/` instead of `System64/`.

**Tested and working (28/09, single player with `MinReadyPlayers=1`):** start on Fire, countdown after the FNN warm-up reset, `MaxPlayers` restored once the match starts, `mutate ar hold` / `mutate ar start`, logging and debug.

**Still to test:**

- [ ] Two clients, `MinReadyPlayers=2`: no timeout in a duel, status message in chat, disconnect during the countdown (start cancelled), `mutate ar status`.
- [ ] Three or more clients: majority timeout, on-screen countdown, player forced ready during the FNN warm-up.
- [ ] Teams (TDM) with `bRequireBalancedTeams=True`.
- [ ] After testing: `AutoReady.ini` with `MinReadyPlayers=2` and `bDebug=False`, edited with the server stopped.

## What AutoReady is and why it exists

AutoReady lets you use **tournament mode** (everyone presses Fire to say "I'm ready") without having to fill the server.

In UT99, tournament mode only starts the match when the number of connected players is **equal** to `MaxPlayers`. With `MaxPlayers=10` and 6 friends at a LAN party, the match never starts: everyone stays in the FNN warm-up, even after pressing Fire.

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

When the countdown starts, FNN resets the warm-up game (scores, weapons, projectiles) and everyone starts from scratch.

## AutoReady.ini parameters

Configuration lives in `System/AutoReady.ini`, section `[AutoReady.AutoReady]`. If the file does not exist, the mutator creates it with default values on first run.

| Parameter | Default | What it does | Recommendation |
|---|---|---|---|
| `MinReadyPlayers` | 2 | Minimum number of present players for AutoReady to start the match. Below this threshold it just waits. | 2 at LAN parties. 1 only for solo testing. |
| `ReadyTimeout` | 30 | Seconds granted to latecomers once more than half is ready. When it expires, everyone is marked ready. | 30–60. Above 10 the on-screen countdown is also shown. |
| `MessageInterval` | 5 | How often (seconds) the status message appears in chat ("2/6 ready…"). | 5–10. |
| `bRequireBalancedTeams` | False | Team games only: waits until the team size difference is at most 1 before starting. | True for TDM/CTF to avoid 4 vs 2. |
| `bDebug` | False | Logs a `[debug]` line on every state change: present, ready, `MaxPlayers`, `CountDown`, state of each player. | True for testing and the first evening, then False. |

**Fixed rule, not configurable:** the timeout starts when **more than half** of present players are ready (2 of 2, 2 of 3, 3 of 4, 4 of 6). In a duel both players must press Fire.

**Warning:** UT reads the `.ini` at startup and rewrites it on shutdown. Edit it **only with the server stopped**, otherwise the change is ignored and then overwritten.

LAN example (same as `AutoReady.ini.example`):

```ini
[AutoReady.AutoReady]
MinReadyPlayers=2
ReadyTimeout=30
MessageInterval=5
bRequireBalancedTeams=False
bDebug=False
```

## Installation, upgrade and VoteSys presets

Installation only requires copying `AutoReady.u` to the server and enabling it in presets with `bTournament=True`.

**First install or upgrade**

1. Stop the server: `sudo systemctl stop ut99-server`.
2. Copy `AutoReady.u` to `/opt/ut99-server/System/` and check its size with `ls -la AutoReady.u` (21,593 bytes for the current v1.2).
3. Do **not** add it to `ServerPackages`: it runs server-side only.
4. Create or update `System/AutoReady.ini` (see Parameters). Lines must not have leading spaces.
5. Start the server: `sudo systemctl start ut99-server`.
6. Check the startup line in the journal: `journalctl -u ut99-server.service --since "5 min ago" | grep "v1.2 active"`.

**Enabling it in a preset** (`VoteSysPresets.ini`, Windows CRLF line endings)

Compared with a normal preset, two lines are enough: the mutator in `Mutators` and `bTournament=True` in `GameSettings`. Keep `MinPlayers` and `InitialBots` at 0 (they are bots and unrelated to AutoReady).

```ini
[VS_PresetConfig9]
PresetName=TEST - DM AutoReady
Abbreviation=
Category=TEST
SortPriority=10
Game=Botpack.DeathMatchPlus
MapListName=
Mutators=AutoReady.AutoReady
GameSettings=MaxPlayers=10
GameSettings=TimeLimit=15
GameSettings=FragLimit=30
GameSettings=bTournament=True
GameSettings=NetWait=15
GameSettings=bUseTranslocator=False
GameSettings=bCoopWeaponMode=False
GameSettings=bMultiWeaponStay=True
GameSettings=bForceRespawn=False
GameSettings=RestartWait=35
GameSettings=MinPlayers=0
GameSettings=InitialBots=0
```

With other mutators (arenas): `Mutators=AutoReady.AutoReady,fnn353.NewNetIG`. Presets with `bTournament=False` do not need AutoReady: if present, it disables itself.

## Admin commands

Commands are typed in the game console. Admin commands require `adminlogin <password>` first.

| Command | Who | Effect |
|---|---|---|
| `mutate ar status` | Anyone | Shows the requester how many players are ready and the full list of who is missing. Also reports an admin hold or a match already started. |
| `mutate ar start` | Admin | Marks all present players ready and clears any hold: the countdown starts on the next second. Centre: "Admin forced start". |
| `mutate ar hold` | Admin | Blocks the automatic start until `mutate ar start`. Stops the timeout and, if the countdown had started, restores the original `MaxPlayers`. Centre, every 3 s: "Start on hold by admin". |

Once the match has started, admin commands reply "match already started". An unknown command replies with the list of valid commands.

## Behaviour for each use case

Reference values: `MaxPlayers=10`, `MinReadyPlayers=2`, `ReadyTimeout=30`. "Ready" = pressed Fire (enters the FNN warm-up with weapons).

| Situation | What happens | Messages |
|---|---|---|
| Only one player connected | No start: below `MinReadyPlayers`. Stays in warm-up. | None |
| Duel, 1 of 2 ready | No timeout (more than half means 2). Waits for the second Fire. | Chat every 5 s: "1/2 ready. Press Fire when you are ready." |
| Duel, 2 of 2 ready | `MaxPlayers` 10 → 2, countdown, match. | Chat: "All players ready (2)" |
| 6 present, 2 ready | Waits: not a majority. | Chat: "2/6 ready. Press Fire…" |
| 6 present, 4 ready | 30 s timeout starts. | Chat: "4/6 ready - forced start in 30s", then remaining time every 5 s |
| Last 10 s of the timeout | Continuous countdown. | Centre, every second: "Forced start in N s - press Fire!" |
| Timeout expired | Latecomers are marked ready, `MaxPlayers` 10 → 6, countdown. | Centre: "Time is up: starting now!" |
| Everyone ready at once | No timeout: `MaxPlayers` 10 → present, countdown. | Chat: "All players ready (N)" |
| Someone leaves during the countdown, ≥ 2 remain | `MaxPlayers` follows the player count, countdown continues. | Log only |
| Fewer than 2 remain during the countdown | Start cancelled, `MaxPlayers` back to 10, waiting again. | Centre: "Not enough players, start cancelled" |
| Someone connects during the countdown (10 s) | Rejected as "server full" or joins as spectator: the server appears full. | None |
| Teams 4 vs 2 with `bRequireBalancedTeams=True` | Does not start until the difference is at most 1. | Chat: "Unbalanced teams (4 vs 2)" |
| Admin: `mutate ar hold` | No start until `start`, even with everyone ready. | Centre every 3 s: "Start on hold by admin" |
| Admin: `mutate ar start` | Everyone ready immediately, countdown. | Centre: "Admin forced start" |
| Match started | `MaxPlayers` back to 10, newcomers join normally. AutoReady stops until the next map. | Log: "match started…" summary |
| Preset with `bTournament=False` | AutoReady does nothing: the match starts with the normal rule (`NetWait`). | Log: "bTournament=False, nothing to do" |
| Gametype not DeathMatchPlus | AutoReady disables itself. | Log: "unsupported gametype, disabled" |

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

**`[debug]` lines (with `bDebug=True`)**: one line per state change, with present, ready, `NumPlayers`, `MaxPlayers`, `CountDown`, timeout, admin hold and, for each player, name, class, `ready`, `spec`, `waiting` and FNN state (`PlayerWaiting`, `PlayerWarmup`). During the countdown one line per second is logged because `CountDown` changes.

**Known issues already encountered**

| Symptom | Cause | Fix |
|---|---|---|
| Startup line shows `MinReady=2` although the `.ini` says 1 | `.ini` edited while the server was running, or lines with leading spaces | Edit with the server stopped, no leading spaces (`sed -i 's/^[[:space:]]*//' AutoReady.ini`) |
| The match "starts normally" without a countdown | That is the FNN warm-up (weapons, respawn), not the match | Check the log for `countdown started` |
| Endless warm-up with everyone ready | Below `MinReadyPlayers`, or an old build (see log, spectator bug) | Check the startup line and the size of `AutoReady.u` |
| `grep AutoReady` on the journal finds nothing | The journal strips the tag | Search the message text (command above) |
| `Unknown Mutator in use: AutoReady.AutoReady` | Message from another component that does not recognise the name | Harmless |

## Known limitations and interaction with FNN, FSB, VoteSys

- **Joining during the countdown:** for the 10 seconds of the countdown `MaxPlayers` equals the player count, so anyone connecting is rejected or joins as a spectator. Unavoidable: the game checks `NumPlayers == MaxPlayers` every second.
- **FNN (fnn353):** pressing Fire puts the player in `PlayerWarmup` with weapons. When the countdown drops below 10, FNN resets everything and puts players back in `PlayerWaiting`, a state in which UT flags them `bIsSpectator=True`. This is why AutoReady identifies spectators only by the `Spectator` class. To verify with 3+ clients: a player forced ready skips the warm-up, but should start normally after the reset.
- **FSB (fsb58):** FSB detects the match start with the same condition as the game (`NumPlayers == MaxPlayers` and everyone ready), so it sees the start forced by AutoReady and resets its stats at the right moment.
- **VoteSys:** applies `GameSettings` after `InitGame`. AutoReady reads `MaxPlayers` only at start time, so it uses the preset value rather than the last match value saved in the `.ini`.
- **Bots:** not counted and never press Fire. Keep `MinPlayers=0` and `InitialBots=0` in AutoReady presets.
- **Centre-screen messages:** use the standard `CriticalEvent` type (light blue, a few seconds). To keep them on screen longer they are re-sent every second (countdown) or every 3 s (admin hold). A custom message class would require `ServerPackages` and a client download: rejected.
- **Gametypes:** DeathMatchPlus and subclasses only (DM, TDM, CTF, Domination, Assault).

## How to rebuild

On Linux, `ucc-bin-amd64` 469e needs a small helper library, otherwise `ucc make` hangs on "Analyzing..." and runs out of memory. (Not yet verified whether 469f still has this bug.)

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

**UnrealScript 469 notes from development:** there is no `Eval()` (the `IfStr` helper is used instead); a string literal cannot span lines; `config(AutoReady)` on the class moves the configuration to `AutoReady.ini`.

## Development log

AutoReady was created because no existing mutator (ClickBoard/PureClickBoard, SmartDM, SmartCTF, IG+) changes the tournament mode start rule. Builds are listed newest first. From now on, changes are tracked in git history; add a row here for each new build.

| Date | Build | What changed | Why |
|---|---|---|---|
| 16/10 | – | Project moved to git; documentation translated to English. | Version control and consistency with the English standard. |
| 28/09 | v1.2 · 21,593 bytes · md5 `68c7c480…` | Timeout only if someone is still missing. Centre countdown in the last 10 s. "On hold" repeated every 3 s. | Testing showed a useless "timeout started" with everyone ready. Centre messages disappeared too soon. |
| 28/09 | v1.2 · 21,157 bytes | Spectators identified only by the `Spectator` class. | **Bug:** after the FNN reset, a player in `PlayerWaiting` has `bIsSpectator=True`, was discarded and the start cancelled after 2 s (endless warm-up). Tested: match started. |
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
- FNN puts players who press Fire into warm-up (`xxServerSetReadyToPlay`) and resets the game when `CountDown` drops below 10 (`xxResetGame`). Not configurable.
- The systemd journal strips the log tag; `ucc.log` is written in 32 KB blocks.
- Copies to the `backup` folder sometimes wrote the old file: always verify size and md5 after each delivery.
